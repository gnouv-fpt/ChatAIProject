from collections.abc import Iterable, Mapping


def validate_catalogue(cases: Iterable[Mapping[str, object]]) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for case in cases:
        case_id = str(case.get("id", ""))
        if not case_id or case_id in seen:
            errors.append(f"invalid or duplicate id: {case_id!r}")
        seen.add(case_id)
        for field in ("title", "precondition", "steps", "expected", "observations"):
            if not case.get(field):
                errors.append(f"{case_id}: missing {field}")
    return errors


def validate_run_record(record: Mapping[str, object]) -> list[str]:
    errors: list[str] = []
    if record.get("attempt") not in (1, 2, 3):
        errors.append("attempt must be 1, 2, or 3")
    observations = record.get("observations")
    if not isinstance(observations, Mapping) or not observations:
        errors.append("observed values are required; SUCCESS alone is not evidence")
    return errors
