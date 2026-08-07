from __future__ import annotations

from collections.abc import Iterable

from backend.models import IdSequence
from backend.services.calculations import prefixed_code_parts


def next_code(prefix: str) -> str:
    sequence, _ = IdSequence.get_or_create(prefix=prefix, defaults={"next_number": 1})
    code = f"{prefix}-{sequence.next_number:03d}"
    sequence.next_number += 1
    sequence.save()
    return code


def sequence_rows(codes: Iterable[str | None], required_prefixes: Iterable[str] = ()) -> list[dict[str, int | str]]:
    next_numbers: dict[str, int] = {prefix: 1 for prefix in required_prefixes}
    for code in codes:
        parts = prefixed_code_parts(code)
        if not parts:
            continue
        prefix, number = parts
        next_numbers[prefix] = max(next_numbers.get(prefix, 1), number + 1)
    return [
        {"prefix": prefix, "next_number": next_number}
        for prefix, next_number in sorted(next_numbers.items())
    ]

