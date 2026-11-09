# Mốc bàn giao phát triển cho nhóm — kiểm tra 22/10/2026

## Bổ sung bàn giao feedback — 27/10/2026

Tiếp tục dùng **`PRM-Lab3-integration`**. Đã thêm hành trình học/tiến độ từng kỳ, theme và thông báo bảng điểm thống nhất, sửa thiếu tín chỉ OCR ảnh hưởng GPA, Figma Home và board states/mapping; Loading prototype 3 giây. [Bảng thay đổi, phiếu test và các giới hạn còn mở](ux-feedback-validation.md).

Kiểm tra mới: analyzer sạch; **50 Flutter tests không cần backend pass**; build APK debug cuối thành công (13,5 giây). Ảnh render widget 360/412 dp dùng fixture synthetic, không thay thế Google/Firestore thật hoặc ARTEMIS. Figma export và ảnh Flutter ở `design/evidence/2026-10-27/` và `evidence/ux/2026-10-27/`.

Mỗi thành viên dùng T1–T6 trong phiếu test, ghi commit/build, thiết bị, expected/observed và evidence rồi tổng hợp. Các mục Google production, Storage/FCM/Analytics/Crashlytics/Remote Config, ARTEMIS và bộ nộp vẫn mở theo phân công; không làm lại phần đã có. Nội dung 22/10 bên dưới là mốc lịch sử.

## Kết luận

Nhánh bàn giao: `PRM-Lab3-integration`, dùng để nhóm phát triển tiếp. Đây chưa phải bản hoàn tất Lab 3/Final. Gói bàn giao bao gồm source/config Firebase, tests và các tài liệu được liệt kê bên dưới.

Nhánh được tạo từ mốc đã kiểm tra; giữ lịch sử các commit sửa CR01/CR02/CR03. Xem Git log của nhánh để biết commit bàn giao mới nhất.

## Git đã kiểm tra trực tiếp

- Remote: `https://github.com/gnouv-fpt/ChatAIProject`.
- Nhánh hiện tại: `akkhanh05-test-groq-api`, HEAD `bdbdae6` tại lúc rà soát trước khi đóng gói; các thay đổi cloud đã được chọn để commit trên nhánh tích hợp.
- Sau fetch: ahead upstream 4 commit; `origin/PRM-dev` là ancestor của HEAD, không có commit từ PRM-dev bị thiếu; HEAD hơn PRM-dev 24 commit.
- Chưa có `origin/PRM-Lab3-integration` trong danh sách nhánh remote tại lúc kiểm tra.
- Bốn commit local gồm cache theo UID, auth gate, tách import ViewModel và tài liệu Lab 3.

## Kiểm tra code và artifact

- `flutter analyze`: sạch sau sửa lỗi mới nhất.
- `flutter test --exclude-tags live`: 45/45 pass, gồm hai regression test xác nhận vẫn đăng xuất được khi hồ sơ đang tải hoặc tải lỗi.
- `flutter build apk --debug`: build cuối sau sửa nút sign out thành công, Gradle 9.7s.
- Firestore rules không đổi so với 9/9 test Enterprise emulator đã pass; log tại `evidence/firebase/2026-10-22/rules-emulator-enterprise.log`.
- `git diff --check`: không có lỗi whitespace; cảnh báo CRLF không phải compile failure.
- Quét file text mới/sửa theo mẫu private key/provider token/OAuth client secret: chỉ khớp public Firebase client keys trong ba file cấu hình dự kiến. Đây không phải audit toàn bộ lịch sử Git.

## Một lỗi vừa sửa khi kiểm tra

`SettingsScreen` trước đây return màn loading/error trước phần account card, làm nút sign out biến mất khi cloud profile chưa tải được. Đã đưa một action đăng xuất vào app bar của hai trạng thái đó. Test: `flutter_app/test/settings_sign_out_test.dart` (loading và error).

## Thành phần gói bàn giao

- Source Flutter auth/persistence/state/error UI; Firebase options; Gradle Google services plugin; pubspec và lock; generated plugin registrants tương ứng.
- `.firebaserc`, `firebase.json`, `firebase/firestore.rules`, indexes, `firebase/package.json`, package lock, `firebase/tests/`.
- Public client config: `flutter_app/android/app/google-services.json`, `flutter_app/web/firebase-config.json` và `lib/firebase_options.dart`.
- Tests mới/sửa; `docs/` về architecture, data model, traceability, cloud amendment, review, tests và phân công 5 thành viên.
- Chọn đúng ảnh/log evidence dùng trong docs. File `.log` đang bị ignore nên nếu cần lưu Git phải add chính xác từng log, không force-add cả thư mục.
- Rà riêng thay đổi Figma/persona/README đã có từ trước; giữ nguyên nội dung của người khác và không gom mù vào commit cloud.

Không đưa `.idea/`, `node_modules/`, build APK/web output, cache `.kotlin/`, firebase-debug.log, firestore-debug.log, token/code đăng nhập, service-account keys hoặc `firebase/rules-analysis.local.md` vào commit bàn giao.

## Cách team chạy

Môi trường đã kiểm: Flutter 3.47.3 stable, Dart 3.13.3. Dùng `pubspec.lock`. Android SDK theo máy từng người, không copy `local.properties` hoặc debug keystore của máy này.

Trong `flutter_app/`:

```powershell
flutter pub get
flutter analyze
flutter test --exclude-tags live
flutter run -d chrome --web-port 8766
```

Android: dùng device ID của máy; thêm SHA-1 debug của từng người vào Firebase Android app rồi lấy lại google-services.json nếu cần. Không giả định debug keystore của cả nhóm có cùng fingerprint.

Backend hiện tại: từ root repository, `python run_backend.py` hoặc lệnh trong backend/README.md. API mặc định emulator Android là `http://10.0.2.2:8000`, Web là `http://localhost:8000`. Chỉ ghi live RAG pass khi đã có backend/model/API credentials hoạt động; không thay bằng mock.

Rules tests: Node >=24.12.0, Java >=21; root repository:

```powershell
npm ci --prefix firebase
npx firebase-tools emulators:exec --only firestore --project demo-flm-lab3 "npm --prefix firebase test"
```

Firestore emulator dùng 8185. Nếu cổng bận, kiểm tra process trước; không dừng dịch vụ không thuộc lượt test này.

## Các gap phải ghi rõ khi gửi nhóm

- Google login và profile/transcript production qua nhiều phiên/tài khoản chưa có end-to-end pass. Emulator Android chưa có Google account; Web từng gặp unauthorized-domain, cần xác minh cấu hình domain thực tế sau thay đổi Console. Không coi auth provider deployment là login pass.
- Ba test `live_backend_e2e_test.dart` trước đó fail do backend/harness; không thuộc con số 45 test pass.
- Chưa có ARTEMIS runs, đủ Firebase instrumentation, web admin/cross-role/Gemini Final hoặc Lab 2/Stitch/prototype nghiệm thu đầy đủ.
- Lab 3 có Storage upload; Final loại Cloud Storage/custom server. Mỗi người làm theo phạm vi tương ứng, không lấy FastAPI/Groq hiện tại thay cho AI Logic Final.

Phân công cụ thể: `docs/team-assignment-lab2-lab3-final.md`.

## Quy trình làm việc của nhóm

Tạo nhánh tích hợp từ mốc hiện tại; stage named paths sau khi rà diff; commit source/config/docs/evidence đã chọn; kiểm tra đúng branch và commit; push nhánh. Gửi team URL nhánh + commit + tài liệu này + bảng phân công. Mỗi người tạo nhánh con và mở PR về nhánh tích hợp.

## Commit đóng gói
`bf03501` chứa cloud persistence, cấu hình Firebase thật, rules/tests và sửa logout trong trạng thái profile loading/error. Tài liệu phân công và hướng dẫn này được commit tiếp theo trên cùng nhánh. Các thay đổi Lab 2/Figma/persona có sẵn trước lượt cloud vẫn được giữ local để rà riêng; không coi đã publish trong gói này.
