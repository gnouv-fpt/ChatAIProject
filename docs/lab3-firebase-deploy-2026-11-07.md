# Firebase deploy verification - 07/11/2026

Project được chọn rõ: `flm-prm323-20261021` (`FLM Student Assistant PRM323`).
CLI login: account đang đăng nhập được xác nhận bằng `firebase login:list`.
Firestore database: `projects/flm-prm323-20261021/databases/flm-app`, Enterprise, Firestore Native.

| Lệnh | Kết quả |
|---|---|
| `firebase deploy --only firestore:rules --project flm-prm323-20261021 --config firebase.json --non-interactive` | Exit 0; compile thành công, upload và release `firebase/firestore.rules` |
| `firebase deploy --only remoteconfig --project flm-prm323-20261021 --config firebase.json --non-interactive` | Exit 0; deploy complete |
| `firebase remoteconfig:get --project flm-prm323-20261021 --output tmp/lab3-validation/remoteconfig-after-deploy.json` | Trả về `next_course_preview_limit=3`, `enable_pe_tips=true` và mô tả đúng source template |
| `firebase deploy --only storage --project flm-prm323-20261021 --config firebase.json --non-interactive` | Exit 1: Firebase Storage chưa được setup; CLI yêu cầu vào Console và bấm Get Started |

Firebase Rules emulator trước deploy: 14/14 test pass. Kết quả này kiểm rule local; chưa chứng minh truy cập production. Không deploy Authentication provider, không push Git.

Storage còn cần chọn bucket location và billing Blaze. Chỉ sau khi bucket được tạo mới deploy `firebase/storage.rules`, kiểm owner/non-owner trên Android và lấy Console evidence. Browser Work hiện bị tắt nên không thể kiểm tra bước setup qua UI trong lượt này.

## Tiếp tục blocker - 08/11/2026

### Kết luận blocker hiện tại

- Project và client config đều trỏ tới `flm-prm323-20261021`; default bucket dự kiến là
  `flm-prm323-20261021.firebasestorage.app`.
- `firebase.json` trỏ Storage Rules tới `firebase/storage.rules`; `.firebaserc` đặt
  đúng default project. Android `google-services.json` và
  `flutter_app/lib/firebase_options.dart` cùng project ID, app ID và bucket.
- Project vẫn theo quyết định Spark/free-only đã ghi trong handoff. Theo tài liệu
  Firebase hiện hành, từ 03/02/2026 Cloud Storage for Firebase yêu cầu Blaze;
  project Spark không thể provision default bucket và request Storage có thể trả
  402/403. Vì vậy đây không còn là bước setup miễn phí bị thiếu mà là blocker về
  billing/ủy quyền.
- Lượt này không tạo bucket, không đổi billing, không deploy rules, không upload
  production và không push Git.

### Console re-check 08/11/2026

- Project vẫn ở Spark, `No-cost ($0/month)`.
- Trang Storage hiển thị rõ: `Storage requires a billing account (Blaze)` và chỉ
  có nút nâng cấp. Không bấm nâng cấp, không tạo bucket.
- Vì vậy owner/non-owner Android production checks vẫn không thể chạy. Các test
  Storage 3/3 trên emulator giữ nhãn local-only.

Nguồn chính thức:

- https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- https://firebase.google.com/docs/storage/android/start
- https://firebase.google.com/docs/rules/manage-deploy

### Audit rule và upload service

Luồng hiện tại khớp nhau ở các điểm sau:

| Thành phần | Contract hiện tại |
|---|---|
| `firebase/storage.rules` | Chỉ cho UID trong path đọc/xóa; create/update cần đăng nhập, đúng UID, PDF 1 byte-10 MiB, filename 10-30 chữ số và metadata `ownerUid` đúng UID. Ngoài `reports/{uid}/{fileName}` mặc định deny. |
| `ReportService.upload` | Tạo `reports/{uid}/{UTC microseconds}.pdf`, dùng `application/pdf`, metadata `ownerUid`, phát progress, lấy download URL rồi ghi metadata Firestore. |
| Firestore report metadata | `users/{uid}/reports/{id}` chứa `path`, `sizeBytes`, `createdAt`; Firestore Rules kiểm owner/path/size riêng. |
| Android composition | `FirebaseStorage.instanceFor(app: ...)` dùng default bucket từ Firebase options; UID lấy từ phiên `AuthViewModel`. |

Lưu ý kiểm thử: `getDownloadURL()` trả URL dài hạn có token có thể chia sẻ và
thu hồi. Không dùng việc account B mở URL do account A đã chia sẻ để kết luận
Storage Rules sai/đúng. Phép kiểm owner/non-owner phải gọi SDK trực tiếp trên
`StorageReference` (`getMetadata`, `getData` hoặc `putData`) trong đúng phiên Auth.

### Kiểm local đã chạy lại

Máy có Node `24.22.1` trong Codex runtime và Firebase CLI `15.34.2` trong
`tmp/firebase-cli`; PATH mặc định chỉ có Node `22.19.0` và không có lệnh
`firebase`. Dùng Node 24 theo engine của `firebase/package.json`.

Ngày 08/11/2026 đã chạy bằng demo project, không có cloud write:

```powershell
firebase emulators:exec --only firestore,auth,storage `
  --project demo-flm-lab3 --config firebase.json `
  "npm --prefix firebase test"
```

Kết quả: 14/14 pass; riêng Storage 3/3 pass:

1. Owner upload/read/delete PDF hợp lệ.
2. Account khác và anonymous không đọc được object của owner.
3. Sai MIME, metadata, path, filename hoặc quá 10 MiB đều bị từ chối.

Các dòng `PERMISSION_DENIED` trong log là expected negative assertions. Warning
Java về `sun.misc.Unsafe` và NPE khi rules runtime shutdown xuất hiện sau khi
test process đã exit 0; không đổi kết quả assertions.

## Runbook deploy Storage Rules - chỉ chạy sau ủy quyền mới

Hai điều kiện bắt buộc trước khi chạy:

1. Chủ project thay đổi quyết định free-only, tự liên kết Cloud Billing/nâng
   Blaze và xác nhận chấp nhận khả năng phát sinh phí.
2. User ủy quyền rõ trong task hiện tại cho việc tạo bucket/deploy rules.

Sau đó thực hiện tuần tự:

1. Mở Firebase Console đúng project `flm-prm323-20261021`, xác nhận plan Blaze.
2. Storage > Get started > chọn location cho default bucket. Location là quyết
   định cần chủ project xác nhận; không tự chọn thay. Các region Always Free của
   Google Cloud Storage và độ trễ tới người dùng Việt Nam là hai trade-off khác
   nhau.
3. Xác nhận bucket thực tế đúng với `storageBucket` trong Android/Web config;
   nếu khác, cập nhật config có kiểm soát trước khi build.
4. Chạy lại 14 rules tests ở demo project.
5. Kiểm đúng account/project rồi mới deploy duy nhất Storage Rules:

   ```powershell
   firebase login:list
   firebase use
   firebase deploy --only storage `
     --project flm-prm323-20261021 `
     --config firebase.json `
     --non-interactive
   ```

6. Mở Storage > Rules, đối chiếu source/release time với
   `firebase/storage.rules`. CLI deploy sẽ ghi đè rule đang có trên Console.
7. Build/cài APK từ đúng commit, sau đó chạy matrix Android bên dưới.

Không gộp `firestore`, `remoteconfig`, `auth` hoặc service khác vào lệnh deploy
Storage. Không xóa object evidence cho tới khi evidence được đối chiếu; cleanup
production cũng là cloud write và cần nằm trong phạm vi được phép.

## Android owner/non-owner verification matrix

Chuẩn bị hai Firebase Authentication test account riêng A và B, không dùng dữ
liệu cá nhân. Ghi lại Firebase UID đã che bớt, commit/build hash, device/AVD,
thời gian Asia/Bangkok và object path; không chụp email/token/download URL đầy đủ.

| ID | Phiên Android | Thao tác bằng Storage SDK | Kết quả bắt buộc |
|---|---|---|---|
| ST-A1 | Account A | Tạo PDF từ bảng điểm test, bấm upload. | Progress kết thúc; path `reports/{uidA}/{10-30 digits}.pdf`; UI báo thành công. |
| ST-A2 | Account A | Đọc metadata hoặc bytes qua `FirebaseStorage.ref(path)`; không dùng HTTP download URL. | Thành công; MIME `application/pdf`, size 1-10 MiB, `ownerUid=uidA`. |
| ST-B1 | Account B | Gọi `getMetadata`/`getData` trên exact path của A. | Thất bại `storage/unauthorized` hoặc permission denied; không nhầm với object-not-found/network error. |
| ST-B2 | Account B | Thử upload một PDF hợp lệ tới một filename mới dưới `reports/{uidA}/...`, với metadata hợp lệ cho path A. | Bị deny. Nếu bất ngờ thành công, đánh dấu security failure và giữ path để A cleanup sau khi được phép. |
| ST-B3 | Account B | Upload cùng PDF bằng luồng app bình thường. | Thành công tại `reports/{uidB}/...`; đây là positive control để chứng minh B có mạng/Auth/Storage hoạt động. |
| ST-ANON | Signed out | Gọi SDK read trên path A. | Bị deny; không dùng URL token. |
| ST-A3 | Quay lại A | Kiểm object A vẫn đọc được và object B không đọc được. | A đọc object A thành công, đọc object B bị deny. |

App hiện chỉ có UI cho positive owner upload và mở download URL; chưa có UI cho
arbitrary-path negative probe. Khi bucket sẵn sàng, negative probes nên được chạy
bằng một debug-only instrumentation/helper gọi Storage SDK, hoặc thêm panel debug
tạm thời có review. Không biến đường dẫn tùy ý thành tính năng release và không
đưa test account/token vào source.

Evidence tối thiểu để đóng blocker:

- Ảnh/video ST-A1 có progress và path đã che UID.
- Storage Console thấy object A đúng path/metadata/size/content type.
- Logcat/test output ST-A2 thành công, ST-B1/ST-B2/ST-ANON permission denied và
  ST-B3 thành công; mỗi log gắn đúng UID phiên nhưng che dữ liệu nhận dạng.
- Storage Rules source + release time sau deploy.
- Ghi rõ URL là shareable token URL, không phải bằng chứng Rules owner-only.

Chỉ sau các bước trên mới đổi trạng thái Storage production từ `Blocked/Not
verified` sang `Verified`. Emulator 14/14 vẫn chỉ là evidence local.
