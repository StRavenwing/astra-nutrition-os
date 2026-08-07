from __future__ import annotations

import os
from pathlib import Path
from threading import Lock
from typing import Any

from backend.config import PROJECT_ROOT
from backend.recognition.nutrition import OCRLine, parse_nutrition_label


class OCRUnavailableError(RuntimeError):
    pass


_engine: Any | None = None
_engine_lock = Lock()
_predict_lock = Lock()


def recognize_nutrition_label_image(image_path: Path) -> dict:
    lines = recognize_text_lines(image_path)
    return parse_nutrition_label(lines)


def recognize_text_lines(image_path: Path) -> list[OCRLine]:
    engine = _get_engine()
    with _predict_lock:
        try:
            output = engine.predict(str(image_path))
        except Exception as exc:
            raise OCRUnavailableError("Не удалось выполнить OCR") from exc
    return _extract_ocr_lines(output)


def _get_engine() -> Any:
    global _engine
    if _engine is not None:
        return _engine

    with _engine_lock:
        if _engine is None:
            _engine = _build_engine()
    return _engine


def _build_engine() -> Any:
    _configure_cache()
    try:
        from paddleocr import PaddleOCR
    except Exception as exc:
        raise OCRUnavailableError("PaddleOCR не установлен") from exc

    try:
        return PaddleOCR(
            lang=os.environ.get("ASTRA_OCR_LANG", "rs_latin"),
            ocr_version=os.environ.get("ASTRA_OCR_VERSION", "PP-OCRv6"),
            text_detection_model_name=os.environ.get("ASTRA_OCR_DET_MODEL", "PP-OCRv6_small_det"),
            text_recognition_model_name=os.environ.get("ASTRA_OCR_REC_MODEL", "PP-OCRv6_small_rec"),
            use_doc_orientation_classify=False,
            use_doc_unwarping=False,
            use_textline_orientation=False,
            text_det_limit_type="max",
            text_det_limit_side_len=int(os.environ.get("ASTRA_OCR_DET_LIMIT_SIDE_LEN", "1280")),
            text_recognition_batch_size=int(os.environ.get("ASTRA_OCR_REC_BATCH_SIZE", "1")),
            cpu_threads=int(os.environ.get("ASTRA_OCR_CPU_THREADS", "2")),
            device="cpu",
            engine="paddle_static",
            enable_hpi=False,
        )
    except Exception as exc:
        raise OCRUnavailableError("Не удалось инициализировать PaddleOCR") from exc


def _configure_cache() -> None:
    cache_root = Path(os.environ.get("ASTRA_OCR_MODEL_CACHE", PROJECT_ROOT / ".data" / "ocr-models"))
    if not cache_root.is_absolute():
        cache_root = PROJECT_ROOT / cache_root
    cache_root.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("PADDLEX_HOME", str(cache_root / "paddlex"))
    os.environ.setdefault("PADDLE_HOME", str(cache_root / "paddle"))
    os.environ.setdefault("PADDLEOCR_HOME", str(cache_root / "paddleocr"))


def _extract_ocr_lines(output: Any) -> list[OCRLine]:
    lines: list[OCRLine] = []
    _collect_lines(output, lines)
    return [line for line in lines if line.text.strip()]


def _collect_lines(node: Any, lines: list[OCRLine]) -> None:
    if node is None or isinstance(node, (str, bytes)):
        return

    payload = _json_payload(node)
    if payload is not None:
        _collect_payload_lines(payload, lines)
        return

    if isinstance(node, dict):
        _collect_payload_lines(node, lines)
        return

    if isinstance(node, tuple) and len(node) >= 2 and isinstance(node[0], str):
        lines.append(OCRLine(node[0], _float_or_none(node[1])))
        return

    if isinstance(node, (list, tuple)):
        if _looks_like_v2_line(node):
            text, score = node[1][0], node[1][1]
            lines.append(OCRLine(str(text), _float_or_none(score)))
            return
        for item in node:
            _collect_lines(item, lines)


def _json_payload(node: Any) -> dict | None:
    value = getattr(node, "json", None)
    if callable(value):
        value = value()
    return value if isinstance(value, dict) else None


def _collect_payload_lines(payload: dict, lines: list[OCRLine]) -> None:
    data = payload.get("res", payload)
    if not isinstance(data, dict):
        return
    texts = _first_payload_value(data, "rec_texts", "texts")
    scores = _first_payload_value(data, "rec_scores", "scores")
    if _is_sequence_like(texts):
        for index, text in enumerate(texts):
            score = scores[index] if _is_sequence_like(scores) and index < len(scores) else None
            lines.append(OCRLine(str(text), _float_or_none(score)))
        return

    for value in data.values():
        _collect_lines(value, lines)


def _first_payload_value(data: dict, *keys: str) -> Any:
    for key in keys:
        if key in data and data[key] is not None:
            return data[key]
    return None


def _is_sequence_like(value: Any) -> bool:
    return (
        value is not None
        and not isinstance(value, (str, bytes, dict))
        and hasattr(value, "__iter__")
        and hasattr(value, "__len__")
        and hasattr(value, "__getitem__")
    )


def _looks_like_v2_line(node: Any) -> bool:
    if not isinstance(node, (list, tuple)) or len(node) < 2:
        return False
    prediction = node[1]
    return (
        isinstance(prediction, (list, tuple))
        and len(prediction) >= 2
        and isinstance(prediction[0], str)
    )


def _float_or_none(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
