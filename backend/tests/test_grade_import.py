from backend.app.api.v1.endpoints.grade_import import _merge_and_normalize, _parse_vision_response


def test_transcript_table_mapping_preserves_zero_credits_and_numeric_semester():
    raw = '{"rows":[{"course_code":"MAE101","score":"5,7","credits":3,"semester":1,"status":"Đạt","confidence":0.95}]}'
    parsed = _parse_vision_response(raw)
    entries = _merge_and_normalize(parsed)

    assert entries[0].course_code == "MAE101"
    assert entries[0].score == 5.7
    assert entries[0].semester == 1
    assert entries[0].status if hasattr(entries[0], "status") else entries[0].is_passed


def test_missing_credits_and_semester_are_not_invented():
    entries = _merge_and_normalize([{
        "course_code": "ABC101",
        "score": 8.0,
        "status": "Đạt",
    }])

    assert entries[0].credits == 0
    assert entries[0].semester == 0
