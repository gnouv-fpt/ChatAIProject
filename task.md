# Phân công hiện hành — C2 mới ngày 27/10/2026

Bản này thay phân công ngày 24/10. Chi tiết: [IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md). Đồng bộ nhánh: [TEAM-GIT-WORKFLOW.md](docs/TEAM-GIT-WORKFLOW.md).

## Phạm vi đã chốt

- Hai SQL DB độc lập: User DB lưu tài khoản/chat/lượt thi; Content/Exam DB lưu luật/chunks/bank câu hỏi/đề mẫu.
- Qdrant lưu vectors RAG. Redis lưu đề custom theo user và TTL; không mặc định lưu đề custom thành đề mẫu SQL.
- Client → Gateway → service → DB tương ứng. Gateway định tuyến API, không truy vấn DB trực tiếp.
- Kafka chỉ truyền notification/event giữa hai service; luồng Kafka/Worker trừ quota trong plan cũ không còn là yêu cầu hiện hành.
- Bỏ bảng RefreshTokens; client giữ token. Bảo/Vương chốt contract expiry/refresh/logout mới trước khi sửa; không giữ lời hứa rotation/revocation dựa trên bảng đã bỏ.
- Animation HTML deploy riêng lên Vercel/GitHub Pages hoặc hosting tương đương; lưu ExplanationAnimationUrl ở câu hỏi trong DB đề.
- Giữ chat chữ/ảnh, RAG có nguồn, học/luyện thi. AI dùng API; chấm thi bằng code theo đáp án chuẩn.

## Phân công

| Người | Phần tiếp tục và điều chỉnh | Bàn giao |
| --- | --- | --- |
| **Vương** | Schema/entities, hai DbContext, mapping/index/constraints, repo contracts, migrations; Gateway/DI/Compose; chat/ảnh/web shell và tích hợp | Schema/contract đầu tiên chốt sớm; migration riêng mỗi DB và kiểm tra tích hợp cuối |
| **Bảo** | Auth/tài khoản; User DB repositories/services; lịch sử chat/lượt thi/progress/report; UI account/progress; phối hợp Vương chat | Module User theo contract, lưu kết quả/snapshot, auth không bảng RefreshTokens |
| **Phúc** | Luật/crawler/chunks; bank/đề mẫu/import/publish; repositories nội dung; UI học/admin; animation URL | SQL Content/Exam là nguồn chính; giữ parser/API/UI dùng được từ code hiện có |
| **Khánh** | Tạo đề custom từ bank/lưu Redis; timer/autosave/chấm/nộp; Kafka notification/Worker handlers giữa hai service; UI thi | Redis ownership/TTL/version; submit idempotent và lưu kết quả User DB qua contract |
| **Khôi** | AI API/gRPC/vision/Qdrant; verification/index/deactivate/metadata | Proto, adapters, citations IDs/version/Điều/Khoản/Điểm |

## Ownership và tiếp tục code

- Vương sở hữu entities/schema, DbContext/configurations, migrations/model snapshots, repo interfaces, host/solution/Gateway/Compose/web shell chung.
- Bảo/Phúc triển khai query/repository/nghiệp vụ theo contract; gửi nhu cầu field/query cho Vương. Không tự sinh migration mới hoặc sửa schema chung độc lập.
- Khánh giữ events/Worker/Redis exam contract; Khôi giữ protobuf nguồn/Python. Mỗi người viết DTO/controller/service/UI/tests/telemetry của module mình; bàn giao DI extension cho owner host.
- Giữ nhánh và commit đã làm. Commit đúng phần đang dở, fetch/merge origin/PRN-dev, đọc plan mới rồi điều chỉnh phần cần đổi; không làm lại từ đầu.
- Trong lúc chờ schema P0, tiếp tục UI/parser/AI/tests không phụ thuộc schema; dừng migration mới.
- Vương chốt schema sớm, rà soát migration tích hợp cuối và lộ trình dữ liệu. Không xóa lịch sử migration hay apply tự động lên DB đang dùng.

## Mốc nghiệm thu

| Mốc | Điều kiện |
| --- | --- |
| P0 | Ranh giới service/DB và schema/API/auth/event/Redis contracts bản đầu |
| P1 | Login qua Gateway; SQL bank; chat User DB và RAG Qdrant đúng ranh giới |
| P2 | Tạo đề custom → Redis → làm/nộp/chấm → lưu kết quả User DB; xem lại sau Redis expiry |
| P3 | Notification giữa service, animation URL thật, chat ảnh và demo tích hợp |

Đây là cập nhật tài liệu/phân công, chưa xác nhận schema mới hoặc code các nhánh đã chạy chung.
