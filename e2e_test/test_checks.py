from cases import CASES
from checks import validate_catalogue, validate_run_record


def test_catalogue_has_ten_complete_cases():
    assert len(CASES) >= 10
    assert validate_catalogue(CASES) == []


def test_catalogue_covers_error_and_native_interaction():
    assert any("error_message" in case["observations"] for case in CASES)
    assert any("native_dialog" in case["observations"] for case in CASES)


def test_run_record_requires_attempt_range_and_observations():
    assert validate_run_record({"attempt": 1, "observations": {"screen": "home"}}) == []
    assert validate_run_record({"attempt": 4, "observations": {}})
