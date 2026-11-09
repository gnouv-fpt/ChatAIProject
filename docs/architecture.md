# Kiến trúc Flutter — trạng thái triển khai 21/10/2026

## Phạm vi
Ứng dụng hiện dùng Provider, các model và service Dart, dữ liệu FLM từ asset có nguồn và RAG FastAPI. Đang chuyển dần sang MVVM; chưa tuyên bố toàn app đạt MVVM hoặc Final không custom server. Firebase đã được provisioning và Google provider đã bật; đăng nhập Google end-to-end còn cần account smoke test.

## Thư mục và hướng phụ thuộc
| Thư mục | Vai trò |
|---|---|
| lib/app | Composition root, bootstrap Firebase và auth gate, shell điều hướng |
| lib/screens, lib/pages, lib/features/*/views | Render UI và chuyển tiếp thao tác |
| lib/state, lib/features/*/providers | ViewModel, trạng thái và orchestration |
| lib/services, lib/features/*/services | API, Google/Firebase authentication, tính toán học vụ |
| lib/data | Repository và adapter lưu trữ theo UID |
| lib/models | Dữ liệu nghiệp vụ |
| lib/theme, lib/widgets | Token và component dùng chung |

```mermaid
flowchart TD
 UI[Screen / Page] --> VM[Provider / ViewModel]
 VM --> Service[Service interfaces]
 Service --> SDK[Firebase / HTTP / SharedPreferences]
 VM --> Model[Domain models]
 UI --> Theme[Theme / Components]
```

## Auth và ranh giới dữ liệu
Production `main` chạy `FirebaseEntry`, khởi tạo SDK rồi inject `AuthService` vào `AuthViewModel`. Chưa cấu hình hoặc lỗi khởi tạo: màn lỗi có Thử lại. Auth đang tải: spinner. Signed out: SignInScreen; signed in: FlmApp có key theo UID. Cây Provider, Navigator và state cũ bị tháo khi đổi UID/đăng xuất.

```mermaid
sequenceDiagram
 actor User
 participant UI as SignInScreen
 participant VM as AuthViewModel
 participant S as FirebaseAuthService
 participant Firebase
 User->>UI: Đăng nhập Google
 UI->>VM: signIn()
 VM->>S: signIn()
 S->>Firebase: Google credential / popup
 Firebase-->>VM: authStateChanges(uid)
 VM-->>UI: signedIn
 Note over UI,VM: AuthGate tạo FlmApp và storage riêng theo UID
```

| ViewModel | Service / dependency | Trạng thái hiện tại |
|---|---|---|
| AuthViewModel | AuthService, PersonalPreferences | loading/signedOut/signedIn/error, busy, message |
| LearningProfileProvider | PersonalDataRepository (cloud) hoặc PersonalPreferences (legacy/test) | loading/empty/error/data, save error, retry |
| TranscriptProvider | PersonalDataRepository / PersonalPreferences, GradeCalculator | loading/empty/error/data, entries, GPA; retry lỗi đọc |
| ChatProvider | ChatApiService, LearningProfileProvider, PersonalPreferences | loading, error, server health, history |
| TranscriptImportViewModel | TranscriptImagePicker, GradeImportService factory | idle/loading/empty/error/data; cancellation, retry, merge theo môn và kỳ |
| CourseCatalog | CourseRepository | dữ liệu chương trình/môn từ nguồn hiện tại |

`PersonalPreferences(uid)` giữ namespace cố định `account/{uid}/`. Tài khoản mới không tự nhận dữ liệu local cũ. Sign out khóa ghi namespace, đóng phiên Firebase, đợi thao tác ghi đang chạy rồi xóa cache của tài khoản đó. Nếu sign out thất bại, mở lại cache cho retry. Không xóa namespace của tài khoản khác hay dữ liệu local cũ.

## Design system
`lib/theme/app_theme.dart`: palette, radius và ThemeData hiện có. Cần tiếp tục gom spacing/elevation/text token và thay one-off widget; không coi tồn tại theme là đã đạt toàn bộ rubric. Link Figma và mapping component nằm trong `docs/design-traceability.md`. Các snapshot/bridge tooling local của lượt chỉnh Figma được rà riêng, chưa coi là deliverable đã khép.

## Các gap còn mở
- Firestore repository và rules đã triển khai; 9 rules emulator tests pass. Chưa chứng minh dữ liệu production qua hai tài khoản/thiết bị.
- Đã chuyển picker/OCR/merge và sort bảng điểm ra khỏi TranscriptScreen; các screen còn lại cần audit tiếp.
- Final cần shared package `packages/core/`, client web và loại dependency FastAPI khỏi luồng nộp Final.
- Profile local-only cũ và cloud Final phải có đặc tả đồng bộ; không tự đưa ảnh bảng điểm vào kho RAG chung.

## Cloud wiring 22/10
FirebaseEntry tạo FirebaseFirestore.instanceFor(databaseId: flm-app), tắt disk persistence của SDK để không giữ dữ liệu cá nhân ngoài cache kiểm soát theo UID. AuthGate chọn repository có UID cố định và truyền vào FlmApp; Provider inject vào profile/transcript ViewModel. Cloud là nguồn chính, lỗi tải có retry; không tự chuyển ảnh hoặc dữ liệu legacy lên cloud. Xem data-model.md.
