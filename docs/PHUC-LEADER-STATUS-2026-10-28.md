# Báo cáo Phúc gửi leader — 28/10/2026

Nhánh: **PRN_Phúc_ASM**, theo task IDs của plan 27/10. Đã đồng bộ nền `origin/PRN-dev` tại `e0d53bb`.

**Còn 6 task lớn có phần chưa hoàn tất (P01–P06).** Cả 6 đã có code/thành phần nền; chưa có task nào được nghiệm thu đầy đủ theo kiến trúc C2 mới. Không quy đổi số file/tests thành phần trăm hoàn thành.

| Task | Đã có | Phần còn lại | Cần từ nhóm |
| --- | --- | --- | --- |
| P01 — crawler/evidence | Parser toàn văn/số hiệu/Điều–Khoản–Điểm; nguồn allowlist; preview hashes/UTC; durable crawl status và tests lỗi. | Xác minh selector trên nguồn thật và lưu evidence theo contract. Lần kiểm tra listing trực tiếp ngày 28/10 trả HTTP 403; chưa crawl thành công dữ liệu thật. | Nguồn truy cập hợp lệ, evidence/sequence/version fields từ Vương. |
| P02 — SQL luật/chunks + index | Orchestration verify/index có gate; expiry SQL handler; đề xuất fields và query đã viết. | Content DbContext/repository SQL đúng ranh giới; citation eligibility API; index/deactivate/version/recovery và nghiệm thu SQL–Qdrant. | Schema/repo contract Vương; proto/eligibility/index/deactivate Khôi; notification contract Khánh. |
| P03 — SQL bank import/publish | Validation bank/profile/options/keys/assets; Admin preflight/hash; immutable import/publish logic cũ; file adapter chỉ dùng fixture/chuyển đổi. | SQL adapter/transaction/import draft/publish; mapping category/version/profile; nhập dữ liệu chuẩn. Runtime đang trả 503 khi cần bank SQL, không ghi song song vào file. | Schema Vương; nguồn bank/profile và assets được nhóm review. |
| P04 — questions/templates APIs | Public DTO ẩn key/lời giải; filter/range/paging; template/profile list; protected Admin APIs/tests. | Query SQL theo contract; category/template-items detail; server-only pool snapshot cho Khánh có service auth; test version/answer visibility xuyên dịch vụ. | Repo interfaces/ID mapping Vương; pool/service-auth contract Khánh; review/result visibility Bảo. |
| P05 — animation URL/hosting | Renderer HTML/CSS/JS; controls; validator HTTPS/exact-host; component review link; packager có hash và static Vercel config. | Animation gắn câu hỏi chính thức; deploy HTTPS thật; kiểm URL và lưu ExplanationAnimationUrl vào Content DB. Hiện chưa upload/deploy theo quyết định tiếp tục phần có sẵn, đợi nguồn bank. | Bank/profile/câu hỏi chuẩn; trường URL trong schema. Vercel đã xác thực, project `chatai-content-animations` đã tạo, dry-run 6 files thành công; chưa có deployment URL. |
| P06 — UI học/admin + cron nội dung | UI thư viện luật/câu hỏi, Admin preflight/evidence/import-preview; callback Practice; expiry handler/startup catch-up/giờ Việt Nam ở host tạm. | Ghép shell/auth, Practice/Progress, SQL publish/import; chuyển đăng ký cron sang Worker, reverify/retention/recovery theo contracts; chạy demo thật. | Shell Vương; Practice/Worker Khánh; Progress Bảo; verification Khôi. |

## Leader cần chốt tiếp

1. **Vương phát hành P0**: contexts/connections/hosts, entities/IDs, sequence/Point/version/evidence, bank/profile/category/template mapping và repository/query contracts. Phúc không tự tạo migration hoặc sửa schema chung.
2. **Nhóm chốt nguồn bank/profile và quyền truy cập nguồn luật**. Hiện chưa có bank chuẩn, không dùng fixture như dữ liệu chính thức. HTTP 403 cần xử lý bằng nguồn/quyền truy cập phù hợp; không vượt CAPTCHA/chặn truy cập.
3. **Chốt contracts tích hợp**: Khôi index/deactivate/citations; Khánh pool snapshot/service auth/notification/Worker; Bảo review/progress/result visibility. Sau đó Phúc nối module và kiểm thử xuyên dịch vụ.

## Bằng chứng kiểm tra

- .NET: lần kiểm tra C2 gần nhất **51 tests pass**, cùng code backend đang bàn giao.
- Frontend: TypeScript/Vite build thành công ở lượt C2 gần nhất.
- Lượt này: **4 tests JavaScript pass**; đóng gói animation fixture thành công với artifact SHA-256 `cc8c0ac1ce2f4baf89384305929aef61095d5a033df0003c78d31ce184021106`.
- Vercel dry-run chỉ gồm 6 file renderer/scenario/config; không upload secrets hoặc backend. **Chưa deploy**, không tính P05 done.
- Chưa chạy tích hợp hai SQL DB/Gateway/Kafka/Qdrant/Redis/Worker; không apply/generate migration.

Chi tiết kỹ thuật: [PHUC-C2-PROGRESS-2026-10-28.md](PHUC-C2-PROGRESS-2026-10-28.md), [PHUC-P0-CONTENT-REQUIREMENTS.md](PHUC-P0-CONTENT-REQUIREMENTS.md).
