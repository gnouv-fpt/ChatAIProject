# Firebase setup — cập nhật 22/10/2026

Project: `flm-prm323-20261021` (number `913094498381`), Spark.
Console: https://console.firebase.google.com/project/flm-prm323-20261021/overview

## Đã xác minh
- Firebase project ACTIVE; Android và Web apps đăng ký bằng CLI.
- Android package `com.example.flm_courses`; debug SHA-1 đã thêm; Google OAuth Android/Web clients được sinh.
- Google Sign-In provider deploy thành công. Danh sách authorizedDomains trong firebase.json là ý định cấu hình; CLI này chưa áp dụng localhost như mong đợi. Đã thực hiện thêm localhost qua Console, còn cần kiểm tra login lại để xác nhận.
- Cấu hình thật: `flutter_app/android/app/google-services.json`, `flutter_app/web/firebase-config.json`, `flutter_app/lib/firebase_options.dart`. Đây là public client config; không phải service-account credential.
- Database `flm-app`: Enterprise, FIRESTORE_NATIVE, asia-southeast1 (Singapore), realtime enabled, freeTier=true. SDK phải chỉ rõ databaseId=flm-app.
- Firestore rules và indexes đã compile/deploy. Mặc định deny, riêng profile/preferences/transcript chỉ owner UID được đọc/ghi; validate cả create/update.
- 9 rules test pass với emulator Enterprise 1.22.0; cổng Firestore 8185. Bản test Standard ban đầu cũng pass nhưng không dùng thay bản Enterprise.
- 43 Flutter unit/widget tests pass (exclude live); analyzer sạch; APK debug build được, cài và mở trên FLM_API36.
- Web release build thành công, dùng tài nguyên render local.

## Vận hành
Từ `flutter_app`: `flutter run -d emulator-5554` hoặc `flutter run -d chrome --web-port 8766`.
FirebaseOptions đã có giá trị thật cho Android/Web; không cần dart define cho chạy thông thường. Các FIREBASE_* dart define vẫn cho phép override project đầy đủ. Google Android lấy web client ID từ google-services resources; GOOGLE_SERVER_CLIENT_ID chỉ để override khi cần.

Rules: dùng Node >=24.12.0, Java >=21, `npm ci --prefix firebase`; chạy `npx firebase-tools emulators:exec --only firestore --project demo-flm-lab3 "npm --prefix firebase test"`. Dùng demo project để không ghi dữ liệu cloud khi test.

## Ranh giới bằng chứng
- Emulator chưa có Google account: đã kiểm tra màn login/lỗi, chưa login native thành công.
- Chưa xác minh profile/transcript production qua hai phiên hoặc hai tài khoản Google. Unit test repository doubles và rules emulator không thay thế bước này.
- Analytics còn yêu cầu terms riêng; chưa tự chấp nhận. Không coi measurementId trong config là DebugView evidence.
- Chưa nối Storage/FCM/Analytics/Crashlytics/Remote Config/App Check.
- Không nâng billing; không tạo service-account key; không commit token/code đăng nhập.

Evidence: `evidence/firebase/2026-10-22/` chứa ảnh app/Console và log checks. Các dòng PERMISSION_DENIED trong log rules là kết quả mong đợi của negative tests.
