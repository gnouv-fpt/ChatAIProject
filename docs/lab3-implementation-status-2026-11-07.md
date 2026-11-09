# Lab 3 implementation status — 07/11/2026

Mục kiến trúc số 2 được bỏ theo yêu cầu. Phạm vi còn lại đã được hiện thực local:

- Auth, Storage PDF/upload, Messaging, Analytics, Crashlytics và Remote Config.
- Firestore/Storage default-deny rules với owner/schema validation và emulator tests.
- ARTEMIS catalogue 10 ca cùng kiểm tra evidence; device run 3× vẫn là bước ngoài máy.
- AI review có sáu findings, quyết định và các fix được chấp nhận.

Chưa được tuyên bố hoàn tất nếu thiếu evidence bên ngoài: Firebase Console,
DebugView/Crashlytics/FCM production, Remote Config publish trước/sau, 30 ARTEMIS
runs, exploratory session, PR/push, report PDF, slide PDF và video. Log ngày 29/10
cho thấy Firestore Rules và Remote Config từng deploy lên `flm-prm323-20261021`;
Storage deploy thất bại vì bucket chưa được khởi tạo.

Lượt 07/11 sau đó: CLI deploy `firestore:rules` và `remoteconfig` thành công lên
`flm-prm323-20261021`; `remoteconfig:get` sau deploy trả về đúng hai key
`next_course_preview_limit=3`, `enable_pe_tips=true` với mô tả trong template.
`storage` deploy vẫn lỗi `Firebase Storage has not been set up` và cần khởi tạo
bucket từ Console. Browser trong Work đang tắt nên chưa kiểm tra giao diện setup.
Chưa có evidence Google login, Storage upload, FCM, Analytics DebugView,
Crashlytics hay Remote Config before/after trên thiết bị. Không push Git.

## Lượt kiểm chứng 07/11 lúc 22:39-22:45 (Asia/Bangkok)

- Firebase Console xác nhận project vẫn ở Spark và màn Storage hiện yêu cầu nâng
  lên Blaze trước khi tạo bucket. Chưa nâng billing; vì vậy chưa thể deploy rules
  hoặc kiểm upload PDF trên production.
- Khởi động `Codex_Lab3_API36` (Android 16/API 36), build/cài debug APK thành
  công và xác nhận app mở đúng màn đăng nhập Google. Account picker chuyển sang
  luồng thiết lập Google của emulator; chưa chọn/nhập tài khoản thay người dùng.
- Bật Analytics debug property cho `com.example.flm_courses`. Log thiết bị xác
  nhận "Faster debug mode event logging enabled", nhưng DebugView vẫn báo 0 debug
  device và 0 event. Chưa đủ bằng chứng Analytics.
- Crashlytics Console, bộ lọc crash trong 7 ngày 01-07/11, báo không có issue.
  Chưa tạo crash/non-fatal vì app chưa qua đăng nhập.
- `flutter analyze` đạt. Toàn suite có 238 test đạt và 3 live-backend test lỗi do
  backend `127.0.0.1:8000` không chạy/HTTP 400; không gọi đây là full-suite pass.
- Sửa setup Firestore rules test để xóa dữ liệu emulator trước suite, tránh lỗi
  phụ thuộc lần chạy trước. Sau khi chạy đủ Firestore + Auth + Storage emulators,
  `npm test` đạt 14/14.
- ARTEMIS catalogue validator đạt 3/3. Chưa chạy 30 device runs hoặc exploratory
  session vì chưa hoàn tất đăng nhập trên emulator và Storage production bị chặn.
- GitHub hiện có 0 pull request mở. AI review hiện vẫn là local review; để thỏa
  đúng yêu cầu PDF cần push nhánh và tạo PR, là hành động remote chưa được phép.

## Quyết định tiếp theo

- Chủ project yêu cầu chỉ dùng gói miễn phí, không liên kết billing và không
  nâng Blaze. Firebase Storage production vì thế không thể tạo bucket/triển khai
  rules theo yêu cầu hiện hành của Console. Giữ kết quả kiểm rules trên emulator
  là bằng chứng local và ghi rõ thiếu bằng chứng production.
- AVD `Codex_Lab3_API36` có `hw.keyboard=no`; đã đổi thành `yes`, dừng emulator
  ẩn và mở lại cửa sổ Android Emulator độc lập để người dùng nhập bằng bàn phím.

## Sau khi người dùng đăng nhập

- Xác nhận trên emulator Android 16: app vào Home và Settings hiển thị tài khoản
  Google đã đồng bộ. Đây là bằng chứng đăng nhập một tài khoản trên một emulator;
  chưa kiểm nhánh hủy/đăng xuất, tài khoản thứ hai hoặc Console Authentication.
- Mở màn Firebase Lab 3 trên phiên thật. Remote Config hiển thị
  `next_course_preview_limit=3`, `enable_pe_tips=true`; chưa đổi tham số và đối
  chiếu hành vi trước/sau trên Console.
- Người dùng đã chấp nhận quyền thông báo Android. Chưa quan sát FCM token hay
  thông báo từ Console ở ba trạng thái; không đánh dấu FCM đạt.
- Bấm `Gửi non-fatal thử nghiệm`, app hiển thị `Đã gửi non-fatal error thử nghiệm.`;
  còn cần xác nhận issue, user ID và custom key trên Crashlytics Console. Chưa
  bấm crash thử nghiệm.

## Kiểm tiếp trên phiên đăng nhập

- Crashlytics Console ghi nhận hai issue từ thao tác FCM trước sửa: đăng ký
  thiết bị bị `API disabled` vì thiếu cờ Firebase Installation ID trong Android
  manifest, kế tiếp là timeout 20 giây. Đã thêm cờ theo hướng dẫn SDK và xử lý
  lỗi thành thông báo trong app. Build/cài lại APK thành công; thử đăng ký lần
  nữa thấy `authorized` và mã thiết bị xuất hiện (chỉ hiển thị 12 ký tự cuối).
- Đã bấm crash thử có xác nhận trên emulator; app đóng, rồi mở lại. Cần chờ và
  xác nhận issue crash mới trên Console; không dùng hai issue cũ làm bằng chứng
  cho crash thử này.
- Remote Config trong app vẫn hiển thị `3`/`true`. Chưa có phép đo before/after
  thay đổi hành vi hoặc fallback mất mạng ở lượt này.

## Lượt thực thi tiếp

- Firebase Console có hai crash issue từ lỗi đăng ký FCM trước khi sửa. Android
  manifest đã bật Firebase Installation ID; cài APK mới và đăng ký lại thành
  công: quyền `authorized`, mã thiết bị hiện trong app. Chưa gửi test message
  foreground/background/terminated vì UI chỉ hiển thị phần cuối mã đăng ký.
- Bấm crash thử có xác nhận: app đóng và khởi động lại. Issue mới trên Console
  chưa được xác nhận; hai issue cũ không được dùng thay thế.
- Remote Config: tắt mạng emulator, bấm refresh, thấy lỗi tiếng Việt và giá trị
  lưu `3/Bật` vẫn còn. Đã publish tạm `2/Tắt` lên Console, nhưng app refresh sau
  khi nối lại Wi-Fi vẫn báo lỗi; do đó chưa có bằng chứng hành vi đổi. Đã deploy
  lại `3/Bật`, `remoteconfig:get` xác nhận version 6 với đúng hai giá trị cũ.
- `flutter analyze --no-pub` sạch; `flutter test --exclude-tags live
  --concurrency=1` đạt 238/238. Chưa có 30 lượt ARTEMIS thực thi.
- Kiểm lại Crashlytics Console sau khi mở app: issue
  `FlutterFirebaseCrashlyticsPlugin.crash / FirebaseCrashlyticsTestCrash`
  xuất hiện riêng với hai issue FCM cũ. Non-fatal demo đã ghi ở log thiết bị,
  nhưng chưa lọc và xác nhận issue non-fatal trên Console.

## Lượt bổ sung 08/11/2026 — free-only, không video

- Giữ project ở Spark; không liên kết billing, không tạo Storage bucket, không
  deploy Storage Rules production và không upload cloud. Storage production
  tiếp tục `Blocked` do Firebase yêu cầu Blaze; rules emulator vẫn 14/14.
- Nối đủ 11 Analytics event theo `docs/analytics-plan.md`. Các event mới phủ
  search, view course/curriculum và transcript import success/error; không log
  query text, điểm hoặc nội dung chat.
- `flutter analyze --no-pub`: sạch. `flutter test --exclude-tags live
  --concurrency=1`: 238/238 pass. `flutter build apk --debug`: thành công.
- Cài APK mới trên `Codex_Lab3_API36`, bật Analytics debug mode và mở chi tiết
  CSD201. DebugView nhận 8 event: `login` 2, `screen_view` 2, `view_course` 2,
  `session_start` 1 và `user_engagement` 1. Log SDK xác nhận parameter
  `course_code=CSD201`, `entry_point=named_route` và HTTP 204.
- ARTEMIS catalogue validator vẫn 3/3; chưa có runner/credential và chưa có 30
  lượt device run, nên không tạo kết quả giả. Manual exploratory Android đã chạy
  15 phút 47 giây và ghi tại `docs/lab3-exploratory-2026-11-08.md`; không đổi
  nhãn session này thành ARTEMIS.
- Báo cáo PDF 12 trang đã tạo lại ngày 08/11. Canva deck 14 slide đã tạo từ
  template 16:9; còn cập nhật evidence và export PDF. Video tiếp tục loại khỏi
  phạm vi.
- Console xác nhận Spark $0/tháng và Storage hiển thị bắt buộc Blaze. Remote
  Config version 6 có 13 fetch/1 user, hai giá trị 3/Bật. Crashlytics có 3 crash,
  gồm test crash; nonfatal/custom key chưa được xác nhận.
- Commit `857afe7` đã push lên `origin/PRM-dev`; PR #5 mở vào `main` tại
  `https://github.com/gnouv-fpt/ChatAIProject/pull/5`, mergeable clean. Không merge,
  không nâng billing. Review cuối phát hiện và sửa CR-L3-07: chỉ ghi
  `transcript_import` sau khi lưu bảng điểm thành công.
