# Android emulator smoke test - 07/11/2026

- Target: fresh `Codex_Lab3_API36` AVD, Android API 36 Google APIs x86_64. The existing `FLM_API36` installation was preserved because its installed app had a different signing certificate.
- Installed `flutter_app/build/app/outputs/flutter-apk/app-debug.apk` with `adb install -r`: `Success`.
- Launched `com.example.flm_courses/.MainActivity`; `pidof` returned a live process and ActivityManager reported it as top resumed.
- The signed-out Google sign-in gate rendered on the emulator. Screenshot: `evidence/lab3/2026-11-07/android-signed-out-avd.png` (ignored by Git, retained locally).
- Tapping Google sign-in opened the Google Play Services account flow. The fresh AVD has no test Google account; its log reported `RETRIEVE_ACCOUNT_LIST; successful=false`. No successful sign-in, cancellation UX, authenticated Home, or Firebase Console Users verification is claimed.
- This is one installation/launch smoke test, not one of the required ARTEMIS runs.

## Lượt tiếp tục 08/11/2026

- Build lại APK sau khi nối đủ 11 Analytics event; `adb install -r` thành công
  trên `Codex_Lab3_API36`, session Google hiện có vẫn vào Home.
- Bật `debug.firebase.analytics.app=com.example.flm_courses`; log SDK xác nhận
  faster debug mode.
- Trên tab Lộ trình, submit `OTP101` và mở đúng màn `Chi tiết môn học`. Log SDK
  ghi hai lượt xử lý `logEvent`; chưa có tên event trong logcat và chưa xác nhận
  DebugView vì Firebase Console yêu cầu đăng nhập lại.
- Đây là manual Android smoke/evidence cho wiring Analytics, không được tính là
  ARTEMIS run và không chứng minh Firebase Console đã nhận event.

## Analytics Console 08/11/2026

- DebugView nhận 8 event trong 30 phút: `login` 2, `screen_view` 2,
  `view_course` 2, `session_start` 1 và `user_engagement` 1.
- Log SDK của lượt mở CSD201 xác nhận `course_code=CSD201`,
  `entry_point=named_route`, debug mode và response HTTP 204.
- Evidence đã loại bỏ vùng user properties/UID:
  `evidence/lab3/2026-11-08/firebase-debugview-redacted.png`.
- Chỉ `login` và `view_course` thuộc 11 event nghiệp vụ; các event còn lại trong
  kế hoạch chưa có DebugView evidence và không được đánh dấu đạt.
