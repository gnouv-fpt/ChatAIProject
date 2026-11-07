# Android emulator smoke test - 07/11/2026

- Target: fresh `Codex_Lab3_API36` AVD, Android API 36 Google APIs x86_64. The existing `FLM_API36` installation was preserved because its installed app had a different signing certificate.
- Installed `flutter_app/build/app/outputs/flutter-apk/app-debug.apk` with `adb install -r`: `Success`.
- Launched `com.example.flm_courses/.MainActivity`; `pidof` returned a live process and ActivityManager reported it as top resumed.
- The signed-out Google sign-in gate rendered on the emulator. Screenshot: `evidence/lab3/2026-11-07/android-signed-out-avd.png` (ignored by Git, retained locally).
- Tapping Google sign-in opened the Google Play Services account flow. The fresh AVD has no test Google account; its log reported `RETRIEVE_ACCOUNT_LIST; successful=false`. No successful sign-in, cancellation UX, authenticated Home, or Firebase Console Users verification is claimed.
- This is one installation/launch smoke test, not one of the required ARTEMIS runs.
