# Phân công 5 thành viên — Lab 2, Lab 3 và Final

Ngày lập: 22/10/2026. Đây là đề xuất cho phạm vi mới, không thay thế lịch sử phân công Lab 1. Thành viên lấy từ bảng nhóm hiện có: Vương, Bảo, Khánh, Phúc, Khôi.

## Phân công chính

| Thành viên | Phạm vi chịu trách nhiệm | Đầu ra bắt buộc | Điều kiện nghiệm thu |
|---|---|---|---|
| **Vương** | **UI/UX và chốt Lab 2.** Persona/success criterion; Figma ≥8 màn, 3 flow, components/variants và instances; prototype có nhánh thay thế, Back, lỗi/phục hồi; Google Stitch và ≥3 vòng cải tiến khác mục tiêu; accessibility; cập nhật thiết kế khi code thay đổi. | Figma page 01–06 và prototype link; `ux/`, `design/`, `ai/ai-design-log.md`, ảnh trước/sau; `handoff/flutter-handoff.md`; phối hợp Bảo hoàn thiện `docs/design-traceability.md`. | Link mở được; 8 màn và 3 flow được kiểm tra thực tế; ≥5 UX findings kèm Accept/Modify/Reject; mỗi vòng Stitch có prompt/output thật và before/after; kiểm 360/412 dp, target ≥48 dp, chữ nội dung ≥14 sp. |
| **Bảo** | **Mobile, kiến trúc và dữ liệu cá nhân.** MVVM với Provider; inject service; theme/component dùng chung; đủ màn/flow từ Lab 2; Google Sign-In, auth routing, cancel/logout; profile/bảng điểm Firestore theo UID; export báo cáo từ dữ liệu đang xem; nối upload/inbox/config/AI UI với service của Khánh/Khôi. | Flutter mobile; model và interface dùng chung trong `packages/core/` phối hợp Khánh; `docs/architecture.md`; mapping route/widget/data source; APK; ảnh Figma so với app; test mobile. | Không SDK/API trực tiếp trong widget ngoài composition root; loading/empty/error/data và retry; đổi A→B không lộ điểm/profile/chat A; đăng nhập lại đọc được dữ liệu cloud; không overflow; file export phản ánh đúng dữ liệu. |
| **Khánh** | **Firebase backend và các dịch vụ Lab 3.** Config project, data model, roles; Firestore rules/indexes và tests; service cloud dùng chung; Storage upload theo UID cho Lab 3; FCM; Analytics; Crashlytics; Remote Config; App Check cho Firestore/AI Logic ở Final. | `firebase/`; `docs/data-model.md`, `docs/analytics-plan.md`; Firebase service code trong package dùng chung; console evidence gắn đúng project; rules test logs và hướng dẫn setup. | Rules deny by default, validate create/update, không tự nâng role; allowed/denied cho từng role/collection được hỗ trợ; Analytics ≥7 events có parameters/DebugView; Crashlytics có non-fatal thật và test crash; ≥2 RC values đổi hành vi không rebuild; FCM đủ 3 trạng thái và tap mở đúng màn; upload có progress/URL/rules. |
| **Phúc** | **Web admin và luồng mobile–web.** Sign-in/reject role sai; management CRUD/archive một entity mobile dùng; queue approve/reject có lý do; dashboard aggregation/chart; announcement form; mobile inbox/realtime phối hợp Bảo; deploy Hosting. | Web admin 4 màn + announcement form; live URL; UI rộng dùng token Lab 2; `docs/cross-role-flow.md`; sequence actor/screen/write/rule/update; checklist web và ảnh từng màn. | Dashboard ≥3 số liệu từ aggregation query +1 chart; loading/empty/error; user thường không vào admin; ít nhất một cross-role flow chạy live 3 lần, đo độ trễ; thông báo xuất hiện ở inbox mobile; URL mở trong cửa sổ ẩn danh. |
| **Khôi** | **Dữ liệu/AI và điều phối QA, hồ sơ nộp.** Kiểm dữ liệu FLM/tiên quyết/nguồn và câu trả lời; Gemini qua Firebase AI Logic; structured output người dùng xác nhận; giữ luồng dùng được khi AI lỗi; tổ chức ARTEMIS, AI code review và tổng hợp report/slide/video từ các thành viên. | `docs/ai-feature.md`; code AI; `e2e_test/`; `docs/test-plan.md`, `docs/test-report.md`, `docs/code-review.md`; README hướng dẫn chạy; report/slides PDF và video links theo từng bài. | AI lấy model/prompt/on-off từ RC, dùng App Check, không gửi PII, output có nhãn/sửa được, log 3 AI events; ≥3 input/output thật +1 failure; ARTEMIS ≥10 cases ×≥3 runs, assert observed values, trace/pass rate, native/error path và exploratory Pro 15–30 phút; ≥5 review findings/≥2 loại, ≥3 fixes có commit riêng; Final review code mới thêm ≥3 findings có quyết định. |

## Trách nhiệm chung để không dồn QA và báo cáo cho một người

- Mỗi người tự viết/test phần mình, xử lý lỗi và bàn giao ảnh/log thật; không giao code chưa chạy cho Khôi kiểm từ đầu.
- Mỗi người đề xuất ít nhất 2 ARTEMIS cases cho phạm vi mình. Khôi hợp nhất coverage, chạy suite và tổng hợp kết quả; người sở hữu tính năng sửa case fail/flaky do code của mình.
- Mỗi người xử lý review findings thuộc phần mình bằng commit nêu finding ID. Khôi quản lý record và link commit.
- Mỗi người viết phần report, slide và quay đoạn demo tính năng mình. Khôi ghép thành bộ nộp thống nhất; cả nhóm kiểm lại các link.
- Người phụ trách chính chịu trách nhiệm nghiệm thu đầu-cuối, kể cả phần phải phối hợp. Chưa có bằng chứng thì để trạng thái mở.

## Các điểm giao nhau phải thống nhất trước khi sửa

| Nội dung | Người chốt chính | Phối hợp | Quy ước |
|---|---|---|---|
| Figma screen/flow/component IDs, tokens và UI deviations | Vương | Bảo, Phúc | Một bộ ID/token cho mobile và web; thay UI phải cập nhật traceability và Figma. |
| `main.dart`, auth gate, Provider registration, routing, theme | Bảo | Khánh, Vương | Không hai người sửa composition root cùng lúc; service mới bàn giao interface trước. |
| Data model, collection paths, roles, transitions, rules | Khánh | Bảo, Phúc, Khôi | Chốt trong `data-model.md` trước khi mỗi client tự tạo field/path. |
| `packages/core/` | Bảo: model/interface; Khánh: cloud adapters | Phúc, Khôi | Dùng chung giữa mobile và web; không copy hai bộ Firestore service. |
| Entity và cross-role flow của Final | Phúc | Khánh, Bảo | Đề xuất phù hợp FLM: sinh viên gửi yêu cầu tư vấn → staff duyệt/từ chối có lý do → mobile cập nhật realtime và inbox. Đây là đề xuất, chưa coi giảng viên đã duyệt vai trò. |
| Gemini contract và Remote Config keys | Khôi | Khánh, Bảo, Phúc | Chốt JSON schema, validation, fallback và keys trước khi dựng UI. |
| Kết quả test, release build và bộ nộp | Khôi | Cả nhóm | Evidence ghi commit/build, device, command, observed result; không gọi unit test là ARTEMIS. |

## Coverage theo danh sách yêu cầu

| Nhóm requirement | Chủ trì | Phần phối hợp bắt buộc |
|---|---|---|
| 1. Chốt Lab 2 | Vương | Bảo/Phúc xác nhận thiết kế triển khai được; cả nhóm walkthrough flow |
| 2. Kiến trúc app và Figma → code | Bảo | Vương mapping thiết kế; Khánh/Khôi inject services |
| 3. Google Sign-In và dữ liệu cá nhân | Bảo | Khánh provisioning, rules, cloud adapter và tests |
| 4. Đủ Firebase Lab 3 | Khánh | Bảo demo area/export/UI; Khôi assertions và evidence |
| 5. ARTEMIS và AI code review | Khôi | Mỗi người ≥2 cases và tự sửa findings thuộc mình |
| 6. Final web/rules/realtime/Gemini | Phúc: web/flow; Khánh: backend; Khôi: AI | Bảo mobile endpoint của cross-role flow; Vương design system |
| 7. Hồ sơ nộp từng bài | Khôi tổng hợp | Mỗi người nộp nội dung, ảnh/log, slide và demo phần mình |

## Thứ tự và mốc nghiệm thu

1. **Khép thiết kế và contract:** Vương chốt Lab 2; Bảo chốt architecture/traceability; Khánh chốt schema/rules; Khôi chốt AI JSON/RC keys; Phúc chốt entity, vai trò và cross-role flow. Các phần có thể chuẩn bị song song nhưng phải thống nhất trước khi tích hợp.
2. **Chạy được Lab 3:** Bảo + Khánh hoàn thiện auth/personal data/export/upload/instrumentation. Vương đối chiếu app với Figma. Khôi chạy các ARTEMIS case khi chức năng tương ứng sẵn sàng; không đợi cuối mới thiết kế tests.
3. **Hoàn thiện Final:** Phúc tích hợp admin/review/announcement; Bảo nối mobile; Khánh khép rules/App Check/shared services; Khôi nối Gemini. Chạy cross-role trên hệ thống deploy 3 lần.
4. **Khóa release và nộp:** sửa fail/flaky và review findings, chốt evidence; mỗi người bàn giao phần trình bày; Khôi tổng hợp và cả nhóm mở thử tất cả link trong cửa sổ ẩn danh.

Không gắn ngày deadline giả khi nhóm chưa cung cấp lịch. Ưu tiên hoàn thiện luồng hiện có; không thêm tính năng chỉ để tăng số lượng.

## Khác biệt Lab 3 và Final phải giữ rõ

- **Lab 3:** có Cloud Storage upload file được tạo từ app, đường dẫn theo UID, progress/URL và rules.
- **Final:** đề loại Cloud Storage, Cloud Functions, App Hosting và custom server. PDF lưu/chia sẻ trên thiết bị, metadata ở Firestore; không đưa FastAPI cũ vào kiến trúc nghiệm thu Final.
- Final cần shared package, web admin, inbox/cross-role và Gemini qua Firebase AI Logic; chatbot FastAPI/Groq cũ không tự thay thế yêu cầu đó.
- Lab 3: report 8–12 trang, slides 12–15, video 5–10 phút. Final: report 10–15 trang, slides 12–15, video 8–12 phút.
- Bản đề hiện ghi chế độ cá nhân trừ khi giảng viên cho phép nhóm. Bảng này phân chia công việc cộng tác cho 5 người; không tự xác nhận nhóm được nộp chung hoặc dùng chung evidence để chấm cá nhân. Các placeholder `[N] commits/[N] days` và `[date]` phải lấy giá trị giảng viên chốt, không tự đặt.

## Kế thừa phần đã làm

Đã có code Provider/service/theme, các màn FLM, auth gate/cache theo UID; Firebase project và Google provider đã bật; Firestore flm-app/Singapore đã tạo, có rules/service cá nhân và tests. Các thành viên tiếp quản bằng cách kiểm tra source, diff và logs hiện tại, không làm lại từ đầu và không tự đánh dấu đã hoàn thành.

Còn mở: login/persistence Google production end-to-end; chốt Lab 2/Stitch/prototype; đầy đủ Firebase instrumentation; ARTEMIS thực chạy; web admin/cross-role/Gemini và hồ sơ nộp. Kết quả developer test hiện có không thay thế các mục còn mở.
