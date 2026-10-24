# PRN232 — Phạm vi luồng theo review của giảng viên

Cập nhật 22/10/2026: bỏ hai bảng ViolationLogs và UsageReports. SQL giữ 7 bảng: Users, RefreshTokens, LegalDocuments, DocumentChunks, ChatSessions, ChatMessages, Citations. Không coi hai bảng đã bỏ là thiếu sót trong sơ đồ của nhóm.

## Luồng chính

1. Client đăng nhập REST API, nhận JWT/refresh token.
2. Client gửi câu hỏi tới phiên chat. REST kiểm tra user/quota, gọi gRPC.
3. gRPC kiểm duyệt; nếu hợp lệ thì tìm các đoạn luật đã xác thực trong Qdrant, sinh câu trả lời và citations; thiếu căn cứ thì trả no-match.
4. REST lưu ChatMessages/citations và phát ChatCompletedEvent qua Kafka.
5. Worker nhận event, cập nhật TokenBalance một lần, ghi log file; nếu vi phạm thì gửi cảnh báo theo yêu cầu. Không insert bảng log vi phạm riêng.
6. Metrics/logs thể hiện produce/consume/process, retry, lỗi, consumer lag và request/response trên Grafana. Không dùng log mô phỏng làm bằng chứng gửi Kafka.
7. Cron dọn phiên rỗng, kiểm tra hiệu lực văn bản, tổng hợp báo cáo từ ChatMessages theo ngày và xuất file/log; không insert bảng báo cáo riêng.

## File

- PRN232-C2-ERD-Database-Monitoring.drawio: bản editable cập nhật còn 4 trang; gồm C2 nháp trước đây, ERD 7 bảng, physical diagram 7 bảng và monitoring. C2 vẫn là phần nhóm bổ sung riêng sau.
- REVIEW-C2-DOWNLOADED.md: review bản PNG mới tải, đã bỏ nhận xét yêu cầu thêm hai bảng.
- Original-recovered.drawio: bản gốc khôi phục nguyên nội dung PNG cũ, chỉ giữ làm tham chiếu lịch sử, không phải schema mới.
- SVG/PNG: preview sinh từ cùng dữ liệu bố cục; draw.io có thể tự định tuyến đường nối khác.

## Trạng thái triển khai

Đã bỏ hai entities/DbSets/configuration và tạo migration RemoveUnnecessaryReportingTables. Chưa apply migration lên database. Migration sẽ xóa dữ liệu của hai bảng khi áp dụng; migration Down chỉ tạo lại cấu trúc, không phục hồi dữ liệu đã xóa. API có MigrateOnStartup nên lần chạy API với cấu hình này bật cũng có thể áp dụng migration.

Kafka, Worker thật, file logging và stack Grafana trong requirement vẫn là yêu cầu triển khai, chưa được xác nhận chạy bởi thay đổi schema này. Báo cáo có thể tổng hợp ChatMessages/ChatSessions; dữ liệu telemetry theo retention riêng, không phải audit SQL vĩnh viễn.

Script build_diagrams.py tái sinh draw.io/SVG bằng stdlib; dữ liệu cột từ InitialCreate được lọc theo phạm vi 7 bảng hiện tại. Không sửa lịch sử migration cũ để giả định hai bảng chưa từng tồn tại.
