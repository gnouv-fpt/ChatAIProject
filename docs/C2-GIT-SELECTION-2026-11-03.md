# Lọc file cho bản bàn giao demo C2 — 03/11/2026

Phạm vi đã chốt: 600 câu, 115 animation được duyệt, profile B, VBHN 55 Điều 1–89, chat chữ/ảnh, thi/review, Kafka/Worker và monitoring. Báo cáo này ghi lại bước lọc file trước khi commit; trạng thái Git sau bước này cần xem bằng `git status` và `git log`.

## Giữ để bàn giao

- Source, migrations, cấu hình không chứa secret, tests và launcher trong `ApiGateway/`, `BusinessLogic/`, `BusinessLogic.Tests/`, `DataAccess/`, `Presentation/`, `Protos/`, `WorkerService/`, `grpc_inference_service/`, `monitoring/`, `scripts/`, `tests/`, `web/`, các Compose file, `.env.example` và `.gitignore`.
- Toàn bộ `content-animations/` hiện tại, gồm 115 trang learner, `bank-review/scenes.json`, `accepted-release.json`, ảnh gốc, clean plates, GLB và nguồn/license của model. `.gitignore` trong thư mục này giữ quy tắc bỏ `.vercel` khi dùng thư mục độc lập.
- `content-bank/csgt-2025/`, `content-bank/csgt-2025-B-current/`, `content-bank/csgt-2025-https/` và dữ liệu VBHN 55 trong `content-bank/legal/`, gồm PDF ký/capture nguồn. Giữ `rag-eval-source-cases.json` để tái kiểm RAG.
- `docs/` để giữ bằng chứng, giới hạn và runbook dựng lại demo.

## Loại khỏi tập commit, giữ nguyên trên máy

- `.env`, `artifacts/`, `output/`, `tmp/`, `.vercel`, `web/dist/`, `node_modules/` và cache/build output: file local, secret, log, screenshot hoặc kết quả thử nghiệm. Đã bổ sung `output/` và `tmp/` vào `.gitignore`; hai thư mục này có 5.074 file untracked trước khi lọc. Bốn ảnh `output/playwright/c2-*` đã nằm trong HEAD từ trước, không bị `.gitignore` tự xóa và không có trong thay đổi cần commit lần này.
- Bốn file `content-bank/legal/168-2024-source-reviewed.json`, `168-238-consolidation-review.json`, `238-2026-amendment-candidates.json`, `238-2026-source-reviewed.json`: dữ liệu chế tài inactive, ngoài phạm vi demo đã chốt.
- Ba script `scripts/prepare-reviewed-sanctions-168.py`, `prepare-reviewed-sanctions-238.py`, `prepare-sanction-consolidation-review.py`: chỉ phục vụ dữ liệu chế tài ngoài demo.
- `scripts/check-c2-finalization-state.py`: cổng kiểm cũ còn kỳ vọng corpus 333 chunks, không phù hợp edition 4; dùng `check-legal-corpus-extension.py` thay thế.

## Đối chiếu trước commit

Tại thời điểm lọc, sau `.gitignore` có 982 mục Git cần xem (75 file tracked đã sửa, 907 file mới). Trừ đúng tám file ngoài phạm vi/cổng cũ ở trên, tập chọn trước khi tạo báo cáo này là **974 file** (75 đã sửa, 899 mới), khoảng **110,6 MB**. Không file đơn nào đạt 100 MB; GLB lớn nhất khoảng 20,9 MB. File báo cáo này làm số file mới tăng thêm một. Danh sách path chính xác được lưu local tại `artifacts/git-handoff/selected-paths.nul` (Git ignored); không dùng `git add .`.

Quét các file text ứng viên không thấy chuỗi key Groq/Google/OpenAI hoặc private key theo mẫu đã biết. Năm kết quả nghi vấn `password` đều nằm trong test fixture; đây là quét mẫu, không thay thế rà soát diff trước commit. `.env` và runtime JSON đã được xác nhận Git ignore. Bank HTTPS đã qua kiểm 600 câu/319 ảnh/115 link; corpus edition 4 đạt 975 SQL chunks = 975 Qdrant points. Dựng từ clone sạch ở máy khác vẫn chưa được kiểm.
