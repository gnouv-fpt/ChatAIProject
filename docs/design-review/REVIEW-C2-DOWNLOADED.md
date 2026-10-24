# Review sơ đồ database vừa tải — cập nhật theo giảng viên

Nguồn: Diagram PRN232-C2 — Database ERD Diagram.drawio.png trong thư mục Assigment. Đã xem ảnh và mxfile nhúng, đối chiếu source. Không sửa ảnh gốc.

## Phạm vi đã chốt

**7 bảng trong sơ đồ là đủ phạm vi hiện tại. Không bổ sung ViolationLogs hoặc UsageReports.** Vi phạm dùng ChatMessages.IsViolation và log file; báo cáo đọc tổng hợp ChatMessages/ChatSessions hoặc metrics. Model đã được thu gọn và migration xóa hai bảng được chuẩn bị, chưa apply DB.

## Tập trung luồng

Client → REST/JWT → gRPC moderation → Qdrant retrieval → RAG/citations → REST lưu tin nhắn → Kafka → Worker cập nhật quota/ghi log/cảnh báo → Grafana theo dõi. Cron dọn phiên, kiểm tra hiệu lực, xuất báo cáo từ tin nhắn. C2 Container bổ sung sau, không yêu cầu vẽ lại ngay.

## Các điểm cần thống nhất để luồng chạy đúng

- Users cần TokenQuota/TokenBalance để kiểm tra và cập nhật hạn ngạch.
- RefreshTokens: source dùng RevokedAt datetime2 NULL thay vì IsRevoked; role persisted là User/Admin thay vì Citizen/Admin.
- Citations.DocumentChunkId hiện nullable; muốn trace về chunk phải truyền ID từ gRPC và lưu mapping. Các snapshot DocumentTitle/ArticleNumber/ClauseNumber đã có trong source, sơ đồ cần phản ánh nếu cập nhật.
- Cần trích dẫn tách được Điều/Khoản/Điểm; hiện Clause đang gộp Khoản/Điểm. Chốt cấu trúc trước khi sửa dữ liệu.
- Qdrant source dùng collection traffic_law_documents. Point ID hiện là số nguyên băm từ chunk_id, payload giữ chunk_id riêng; sơ đồ ghi UUID/String khớp VectorId cần thống nhất với cách ingest thực tế.
- Chiều vector phải khớp model/config đã chọn; engine hiện 384 hoặc 768, chưa có đường 1536 trong source đã đọc.
- Khi hiệu lực văn bản đổi, cần cập nhật payload/filter Qdrant; hai cờ is_verified/is_active không tự đồng bộ từ SQL.
- Publish/consume cần EventId/correlation để theo dõi, retry không trừ quota trùng. Đếm các bước qua metrics và log file thật, không đếm tổng dòng log thành tổng event.

Đây là review thiết kế/source, chưa phải kiểm chứng runtime SQL/Kafka/Qdrant. Các góp ý kiểu dữ liệu/index chỉ cần hoàn thiện khi nhóm làm physical database diagram; không thêm bảng nghiệp vụ ngoài phạm vi chỉ để phục vụ báo cáo/ghi log.
