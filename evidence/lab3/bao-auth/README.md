# AUTH-01 evidence — Bảo

Build: debug APK from branch `prm-bao-dev` (commit `642ced6` + this commit).
Device: Android emulator Medium Phone, API 37 (Google Play image).
Firebase project: `flm-prm323-20261021`, Firestore database `flm-app`.
Accounts: two separate Google test accounts, called **A** and **B** below (emails omitted).
Date: 2026-10-29. Run 1 of 3 (ARTEMIS runs still to do).

## TC01 — Google sign-in

| Step | Expected | Observed | Evidence |
|---|---|---|---|
| Tap "Đăng nhập với Google", pick A | Native account picker, then home screen | Picker shown; home screen opened | `TC01-google-signin-success-2026-10-29.png` |

## TC12 — Logout and switch A → B

| Step | Expected | Observed | Evidence |
|---|---|---|---|
| A adds PRF192, score 8.5, semester 1, saves | Transcript shows course, GPA 8.50 | As expected | `TC12-01-accountA-transcript-saved.png` |
| Force-stop and reopen app as A | Same data loaded from Firestore | PRF192 8.5, GPA 8.50 | `TC12-02-accountA-after-reopen.png` |
| Settings → Đăng xuất | Sign-in screen | Sign-in screen | `TC12-03-logout-to-signin.png` |
| Press Back, reopen app | No private screen; still signed out | Back exits to launcher; reopen shows sign-in | `TC12-04-reopen-after-back-still-signed-out.png` |
| Sign in as B, open Bảng điểm | B does not see A's data | "Chưa có bảng điểm", no GPA | `TC12-05-accountB-empty-transcript.png` |
| Sign out B, sign in as A, open Bảng điểm | A's data intact | PRF192 8.5, GPA 8.50 | `TC12-06-accountA-data-restored.png` |

## Setup issues found

- A new machine's debug SHA-1 must be added in two places: Firebase Project settings (then re-download `google-services.json`) and Google Cloud Console → Credentials → "Android key (auto created by Firebase)" → Android restrictions. Without the second, Firebase returns `unknown` / "Requests from this Android client application … are blocked".
- An emulator with no Google account makes Google sign-in report "canceled", so the app shows "Bạn đã hủy đăng nhập." even though the user did not cancel.
- The repo path `D:\kỳ 8\…` is non-ASCII; Gradle and the Dart analyzer fail on it. Build through `subst P: "D:\kỳ 8\LAB3_PRM393"`.

## Not yet verified

- Network error → retry on device (offline emulator).
- Cancel message on device with an account present.
- ARTEMIS runs 2 and 3 for TC01 and TC12.
