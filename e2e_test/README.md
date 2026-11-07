# ARTEMIS Lab 3

`cases.py` defines 10 evidence-oriented cases covering Lab 2, error branches,
Firebase flows, and an Android-native permission interaction.

For submission, run every case three times on Android. Each run must include the
named observed values; a bare ARTEMIS `SUCCESS` is insufficient. Save timestamped
logs under `evidence/artemis/`, report pass rate per case, then run and document a
15–30 minute exploratory session (charter, device, build SHA, notes, defects).

```powershell
e2e_test\.venv\Scripts\python.exe -m pytest e2e_test\test_checks.py -q
```

Real runs require an Android target and ARTEMIS/model credentials. Credentials
and fabricated run logs are intentionally not stored in this repository.
