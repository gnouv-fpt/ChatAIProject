# Kế hoạch chia việc Lab 3 — 27/10/2026

Đề xuất cho Vương, Bảo, Khánh, Phúc, Khôi. Dùng bản hiện tại trên `PRM-Lab3-integration`; không bắt đầu lại từ `main` hoặc `PRM-dev`. Kế hoạch này cập nhật **phần Lab 3** của bản phân công 22/10; web admin/cross-role/Gemini AI Logic của Final để giai đoạn sau. Không tự đặt deadline khi nhóm chưa chốt lịch.

## Baseline chung

- Đã có Flutter/Provider, Google auth gate, service Firestore theo UID và rules tests; login/cloud production đầu-cuối còn cần nghiệm thu.
- Đã sửa hành trình học, thiếu tín chỉ OCR, theme/thông báo; Figma có Design System một trang và canvas theo khu. Còn deviations trong `design-traceability.md`.
- Lượt kiểm gần nhất: 50 Flutter unit/widget tests, 5 backend unittest pass; analyzer sạch, APK debug build được. Đây không phải kết quả ARTEMIS hay Google/Firebase thật.
- Chưa thấy package tích hợp Storage/FCM/Analytics/Crashlytics/Remote Config trong `flutter_app/pubspec.yaml`. Các phần này là việc triển khai + nghiệm thu, không chỉ thêm ảnh Console.

## Phân công theo tính năng chạy đầu-cuối

| Chủ trì | Task | Phạm vi phải bàn giao | Điều kiện Done |
|---|---|---|---|
| **Vương** | **UX-01: khép UI/Figma. UX-02: review và bộ nộp.** | Đối chiếu màn/3 flow, sửa lệch Figma–app, các trạng thái/component, 360/412 dp và desktop; giữ matrix persona. Điều phối AI PR review, gom report/slides/video từ cả nhóm. | F01–F03 có walkthrough/evidence cả nhánh lỗi và Back; deviations đóng hoặc ghi rõ. Có log internal/user test đúng loại. Review ≥5 findings/≥2 kinds, quyết định và ≥3 accepted fixes ở commit riêng có ID. Bộ nộp đủ phần, link mở được. |
| **Bảo** | **AUTH-01: Google + Firestore thật. APP-01: tích hợp shell.** | Login/cancel/logout, profile/transcript theo UID, persistence; kiểm A/B và mở lại. Sở hữu auth gate/composition root/routing/Provider registration, khung Firebase demo area và build tích hợp. | Tài khoản test đăng nhập được; cancel báo rõ; logout không quay lại màn riêng; mở lại vẫn đúng dữ liệu; B không thấy dữ liệu A; lỗi mạng có retry. Demo area có các tính năng do từng owner bàn giao; APK chạy được. |
| **Khánh** | **MSG-01: FCM. CFG-01: Remote Config.** | Service + ViewModel + notification list/permission/tap routing; Remote Config service + defaults + UI hiển thị/áp dụng giá trị. Phối hợp provisioning Firebase cho nhóm. | FCM nhận foreground/background/terminated, xin quyền Android 13+, có danh sách và tap tới màn đúng. ≥2 RC parameters đổi hành vi không rebuild; lỗi fetch dùng defaults. Có ảnh Console/app và build ID. |
| **Phúc** | **FILE-01: xuất báo cáo. STORE-01: upload.** | Tạo PDF từ bảng điểm/tiến độ đang xem; service upload, progress/cancel/retry nếu hỗ trợ, URL và view demo; `firebase/storage.rules` + kiểm owner/non-owner. | File phản ánh dữ liệu hiện tại, không phải mẫu cố định. Upload `reports/{uid}/...`, hiển thị progress và URL mở được; user khác không đọc/ghi được; lỗi không mất dữ liệu đang xem. Có file/Console evidence và tests. |
| **Khôi** | **OBS-01: Analytics + Crashlytics. QA-01: ARTEMIS runner.** | Instrumentation qua service inject; event plan/DebugView; handled error và crash demo. Thiết lập `e2e_test/`, pinned ARTEMIS commit, fixture/config, runner và bảng tổng hợp kết quả do các owner chạy. | ≥7 events có parameters, UID/reset sau auth, không log PII; mỗi event có DebugView. Non-fatal từ lỗi thật + test crash có UID/custom key. ≥10 ARTEMIS cases ×≥3 runs, assert observed values, trace/pass rate; exploratory Pro 15–30 phút và giải thích flaky/fail/skip. |

**Owner làm cả service, ViewModel, UI phần mình, test và evidence.** Bảo chỉ ghép vào shell, không nhận toàn bộ UI của bốn người còn lại. Khôi dựng runner và tổng hợp, không viết/chạy/sửa thay tất cả test. Vương tổng hợp trình bày, không viết lại toàn bộ nội dung cho mọi người.

Vương/Bảo đối chiếu ≥8 màn nghiệp vụ distinct với Figma; không lấy 11 frame gồm state/entry cũ làm bằng chứng đủ màn. Màn Chương trình S08 và các deviations hiện còn mở phải có kết luận riêng trước nghiệm thu.

## Hợp đồng cần chốt ở chặng đầu

| Điểm chung | Người chốt | Quy ước đề xuất |
|---|---|---|
| `main.dart`, auth gate, Provider registration, routing | Bảo | Từng owner cung cấp factory/interface/view; Bảo tích hợp tuần tự. Không nhiều PR cùng sửa composition root. |
| Theme/component/Figma IDs | Vương | Dùng theme hiện tại; đổi UI cập nhật Figma + traceability. Không tự thêm bảng màu mới. |
| Dependencies và lockfile | Bảo điều phối | Các owner báo package/version cần thêm; ghép dependency tuần tự, không ghi đè lockfile của nhau. |
| Firestore UID/schema | Bảo + Khánh | Dùng `flm-app` hiện tại; thay schema/rules cần thống nhất trước; notification collection nếu cần phải có owner và rules. |
| Storage path/rules | Phúc | `reports/{uid}/{fileId}.pdf`; metadata tối thiểu, giới hạn loại/kích thước và owner access được đặc tả trong PR. |
| FCM payload và route | Khánh + Bảo | Contract có mã notification, loại đích và `course_code` khi đích là môn; xử lý payload sai/không tìm thấy môn. Không tạo notification chứa điểm hay dữ liệu riêng. |
| Remote Config | Khánh + Vương | Đề xuất `next_course_preview_limit` (int, default 3, validate range) và `enable_pe_tips` (bool). Hai giá trị phải tác động UI thật, không chỉ in ra màn demo; không đổi thuật toán GPA. |
| Analytics | Khôi + mọi owner | Kế thừa `analytics-plan.md`; owner gọi service sau hành động thành công/thất bại thật, Khôi kiểm event/params. |
| Dữ liệu test | Khôi + Bảo | Tài khoản Google test riêng; fixture có điểm/chưa có điểm, biết kết quả kỳ vọng; credentials/API keys ngoài Git. |

Keys/path ở bảng này là **contract đề xuất cần thống nhất trong nhóm**, chưa phải chức năng đã có. Không chấp nhận điều khoản, thay billing hay tạo credentials để thay người có quyền quản trị; báo blocker cụ thể nếu thiếu quyền/quota/cấu hình.

## Bốn chặng thực hiện

### Chặng 1 — mọi người chạy được cùng một baseline

- Cả nhóm pull nhánh chung, `flutter pub get`, analyze/test và chạy trên Android của mình. Bảo/Khánh kiểm debug SHA-1/config theo máy khi cần.
- Bảo làm một lượt Google login thật sớm để phát hiện blocker; người khác vẫn triển khai/test service qua injected fakes trong lúc chờ, không gọi fake là cloud pass.
- Chốt contract ở trên, người sở hữu file chung, tài khoản test và nơi đặt evidence. Khôi dựng smoke ARTEMIS ban đầu, tránh tới cuối mới phát hiện không chạy được tool.
- Vương mở ba flow prototype và lập issue cụ thể cho các gap còn lại; không làm lại Design System vừa có.

**Gate:** mọi người build baseline được; interfaces/path/event/route đã thống nhất; blocker quyền/cấu hình có người xử lý.

### Chặng 2 — hoàn thành từng tính năng

- Bảo: auth + cloud account isolation/persistence; Khánh: FCM + RC; Phúc: export + Storage; Khôi: Analytics/Crashlytics + runner; Vương: UI/Figma và PR review.
- Mỗi owner bàn giao một PR nhỏ có tính năng đầu-cuối, error path, tests và bằng chứng đúng project. Đừng gom mọi dịch vụ vào một PR lớn.
- Vương review UI; Bảo review điểm tích hợp; owner thứ hai kiểm service/rules. Reviewer sửa theo nhận xét có lý do, không chỉ bấm approve.

**Gate:** có thể mở demo area từ một build và biểu diễn từng dịch vụ bằng thao tác thật. PR chưa có cloud evidence có thể merge phần chuẩn bị nếu ghi rõ trạng thái, nhưng chưa tính feature Done.

### Chặng 3 — tích hợp và kiểm thử trên cùng build

- Merge theo phụ thuộc: auth/contracts → export + Storage, FCM, RC → hoàn tất instrumentation trên các flow đã ghép.
- Sau mỗi merge chạy checks phù hợp; sau khi ghép xong khóa một commit/build để chạy toàn suite. Sửa fail/flaky trên build mới và ghi rõ case nào chạy lại.
- Mỗi owner chạy hai ARTEMIS cases chính của mình **ít nhất ba lần**, bàn giao structured observed values + assertion + traces. Khôi điều phối native/analytics coverage và exploratory.

| Owner | Hai cases chủ trì | Điều kiện |
|---|---|---|
| Vương | TC03 hành trình/tiên quyết; TC08 navigation/detail/Back | F01 và UI consistency, kiểm giá trị hiển thị |
| Bảo | TC01 Google sign-in; TC12 logout/đổi A→B | Có native account picker và dữ liệu test phân biệt |
| Khánh | TC11 RC; TC13 FCM | RC đổi hành vi; notification permission/tap có trace |
| Phúc | TC06 OCR lỗi → nhập tay; TC10 export/upload | F03 có recovery; nội dung file/path/URL đúng |
| Khôi | TC05 contextual chat; TC14 Analytics | F02 có nguồn/giới hạn; kiểm event qua Logcat hoặc DebugView |

Đây là 10 cases tối thiểu phân công từ `test-plan.md`. Sau rà coverage, bổ sung TC02/TC04/TC09/TC15 hoặc cases khác khi thiếu cancel/alternate/search/network path. Không coi 10 cases này tự động phủ đủ mọi yêu cầu.

**Gate:** mọi Lab 2 flow có happy/alternate/error path cần thiết; suite có ≥10 cases, đủ ≥3 runs/case và evidence; lỗi còn mở được xử lý hoặc khai báo, không sửa báo cáo thành pass giả.

### Chặng 4 — đóng review và bộ nộp

- Mỗi người gửi phần report, 2–3 slide đề xuất, ảnh/log và đoạn quay tính năng mình; Vương biên tập thành 8–12 trang report, 12–15 slides, video 5–10 phút.
- Mỗi owner sửa findings đã accept thuộc phần mình; ≥3 findings có commit riêng và tên ID. Khôi cập nhật test report; Vương kiểm decision record và AI disclosure.
- Bảo tạo APK từ commit chốt. Cả nhóm mở repo/report/slides/video bằng cửa sổ riêng và tập giải thích phần mình, chạy test/đổi RC live.

**Gate:** bộ nộp mở được; mọi câu “đã chạy” có ảnh/log/trace; người trình bày giải thích được ViewModel, một review decision và kết quả test.

## Git và cách cập nhật tiến độ

- Nhánh tính năng **đề xuất**, chưa tự tạo: `lab3/vuong-ui-review`, `lab3/bao-auth-integration`, `lab3/khanh-fcm-config`, `lab3/phuc-export-storage`, `lab3/khoi-observability-e2e`.
- Mọi nhánh tách từ `origin/PRM-Lab3-integration`; PR về nhánh này. Không force-push nhánh chung; cập nhật baseline trước khi sửa file chung.
- Mỗi task đi qua `Todo → Doing → PR/Review → Verified`. Verified cần build/commit, thao tác thật, expected/observed và evidence; code đã merge chưa tự bằng Verified.
- Cập nhật ngắn sau mỗi phiên làm: **đã xong gì / PR hoặc evidence / đang làm gì / blocker cần ai xử lý**. Báo blocker ngay khi gặp; không để tới buổi ghép cuối.
- PR bàn giao có: Task ID, thay đổi hành vi, cách chạy, dependency, happy/error tests, evidence, phần chưa xác minh. Secrets/account thật không đưa vào log/ảnh public.

Đề hiện ghi cá nhân trừ khi giảng viên cho phép nhóm: tổ chức làm việc chung theo bảng này, còn hình thức nộp/chấm dùng xác nhận của giảng viên. Deadline thực tế và số commits/ngày tối thiểu cần chốt riêng, không tự điền số thay đề.
