from __future__ import annotations

from dataclasses import dataclass
import re
import unicodedata
from typing import Iterable


NutritionBasis = str


@dataclass(frozen=True)
class OCRLine:
    text: str
    confidence: float | None = None
    source_count: int = 1


class NutritionNotFoundError(ValueError):
    pass


_NUMBER_RE = re.compile(r"(?<![\dA-Za-z])(\d{1,4}(?:[.,]\d{1,2})?)(?!\d)")
_PER_100_RE = re.compile(r"(?:per|na|/)\s*100\s*(?:g|gr|gram|grams|ml|мл|г)?")
_SERVING_RE = re.compile(r"\b(?:serving|portion|porcija|porciji)\b")
_KCAL_PATTERNS = (
    re.compile(r"(\d{1,4}(?:[.,]\d{1,2})?)\s*(?:k\s*cal|kcal|cal)\b"),
    re.compile(r"\b(?:k\s*cal|kcal|cal)\D{0,18}(\d{1,4}(?:[.,]\d{1,2})?)"),
)
_ENERGY_LABEL_RE = re.compile(r"\b(?:energy|energetska\s+vrednost|energija)\b")
_MACRO_LABELS = {
    "protein_g": re.compile(r"\b(?:protein|proteins|proteini|proteinima|belancevine|belancevina)\b"),
    "fat_g": re.compile(r"\b(?:total\s+fat|fat|masti|mast|masnoce|masnoca)\b"),
    "carbs_g": re.compile(
        r"\b(?:total\s+carbohydrate|carbohydrates|carbohydrate|carbs|ugljeni\s+hidrati|ugljenih\s+hidrata)\b"
    ),
}
_FIELD_EXCLUDES = {
    "fat_g": re.compile(r"\b(?:saturates|saturated|zasicene|zasicenih|masne\s+kiseline)\b"),
    "carbs_g": re.compile(r"\b(?:sugars|sugar|seceri|secera|secer)\b"),
}
_FIELD_LIMITS = {
    "kcal": 1200.0,
    "protein_g": 100.0,
    "fat_g": 100.0,
    "carbs_g": 100.0,
}


def parse_nutrition_label(lines: Iterable[OCRLine | str]) -> dict:
    ocr_lines: list[OCRLine] = []
    for line in lines:
        ocr_line = _coerce_line(line)
        if ocr_line.text.strip():
            ocr_lines.append(ocr_line)
    raw_text = "\n".join(line.text for line in ocr_lines)
    basis = _detect_basis(raw_text)
    warnings: list[str] = []
    if basis == "unknown":
        warnings.append("Не удалось определить, что значения указаны на 100 г/мл.")

    groups = _line_groups(ocr_lines)
    values: dict[str, float | None] = {
        "kcal": None,
        "protein_g": None,
        "fat_g": None,
        "carbs_g": None,
    }
    field_confidence: dict[str, float] = {}

    for field in values:
        candidate = _find_field(field, groups)
        if candidate is None:
            continue
        value, confidence = candidate
        values[field] = value
        field_confidence[field] = confidence

    found_confidences = list(field_confidence.values())
    if not found_confidences:
        raise NutritionNotFoundError("КБЖУ не найдено на изображении")

    confidence = round(sum(found_confidences) / len(found_confidences), 2)
    if basis == "unknown":
        confidence = round(confidence * 0.85, 2)

    return {
        **values,
        "basis": basis,
        "confidence": confidence,
        "field_confidence": field_confidence,
        "raw_text": raw_text,
        "warnings": warnings,
    }


def _coerce_line(line: OCRLine | str) -> OCRLine:
    if isinstance(line, OCRLine):
        return line
    return OCRLine(str(line), None, 1)


def _fold(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(char for char in value if not unicodedata.combining(char))
    value = value.lower().replace("\u00a0", " ")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def _detect_basis(raw_text: str) -> NutritionBasis:
    return "per_100" if _PER_100_RE.search(_fold(raw_text)) else "unknown"


def _line_groups(lines: list[OCRLine]) -> list[OCRLine]:
    groups: list[OCRLine] = []
    for index, line in enumerate(lines):
        groups.append(line)
        if index + 1 < len(lines):
            groups.append(_merge_lines(lines[index : index + 2]))
        if index + 2 < len(lines):
            groups.append(_merge_lines(lines[index : index + 3]))
    return sorted(groups, key=lambda group: (group.source_count, _group_priority(group)))


def _merge_lines(lines: list[OCRLine]) -> OCRLine:
    confidences = [line.confidence for line in lines if line.confidence is not None]
    confidence = min(confidences) if confidences else None
    return OCRLine(" ".join(line.text for line in lines), confidence, len(lines))


def _group_priority(line: OCRLine) -> int:
    text = _fold(line.text)
    if _PER_100_RE.search(text):
        return 0
    if _SERVING_RE.search(text):
        return 2
    return 1


def _find_field(field: str, groups: list[OCRLine]) -> tuple[float, float] | None:
    for group in groups:
        text = _fold(group.text)
        value = _extract_kcal(text) if field == "kcal" else _extract_macro(field, text)
        if value is None:
            continue
        if value > _FIELD_LIMITS[field]:
            continue
        return round(value, 2), _line_confidence(group)
    return None


def _extract_kcal(text: str) -> float | None:
    if not _ENERGY_LABEL_RE.search(text) and "kcal" not in text and "cal" not in text:
        return None
    for pattern in _KCAL_PATTERNS:
        for match in pattern.finditer(text):
            value = _parse_number(match.group(1))
            if value is not None:
                return value
    return None


def _extract_macro(field: str, text: str) -> float | None:
    label_match = _MACRO_LABELS[field].search(text)
    if label_match is None:
        return None

    exclude = _FIELD_EXCLUDES.get(field)
    exclude_match = exclude.search(text) if exclude else None
    if exclude_match and exclude_match.start() < label_match.start():
        return None

    tail = text[label_match.end() :]
    for match in _NUMBER_RE.finditer(tail):
        if _is_basis_number(tail, match):
            continue
        value = _parse_number(match.group(1))
        if value is not None:
            return value
    return None


def _parse_number(value: str) -> float | None:
    try:
        return float(value.replace(",", "."))
    except ValueError:
        return None


def _is_basis_number(text: str, match: re.Match[str]) -> bool:
    if match.group(1).replace(",", ".") != "100":
        return False
    before = text[max(0, match.start() - 8) : match.start()]
    after = text[match.end() : match.end() + 4]
    return bool(re.search(r"(?:per|na|/)\s*$", before) and re.match(r"\s*(?:g|gr|ml)\b", after))


def _line_confidence(line: OCRLine) -> float:
    if line.confidence is None:
        return 0.65
    return round(max(0.0, min(1.0, float(line.confidence))), 2)
