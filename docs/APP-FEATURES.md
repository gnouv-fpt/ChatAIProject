# Danh sách tính năng app PRN232

Cập nhật 24/10/2026 theo requirement, C0/C1/C2, code các nhánh PRN và yêu cầu dùng AI qua API. “Có source” không đồng nghĩa đã test runtime hoặc đã merge vào nhánh tích hợp. Các thay đổi API-only ở đây là scope/plan, chưa triển khai runtime.

## 1. Tài khoản và quyền truy cập

| Tính năng | Hiện trạng source | Người chính |
| --- | --- | --- |
| Đăng ký tài khoản | Có ở Bảo và các nhánh kế thừa | Bảo |
| Đăng nhập nhận JWT/access token và refresh token | Có | Bảo |
| Refresh token xoay vòng một lần dùng | Có | Bảo |
| Đăng xuất/thu hồi refresh token | Có | Bảo |
| Xem hồ sơ, quota và số dư hiện tại | Có nền profile; cần kiểm tra quota runtime | Bảo |
| Phân quyền User/Admin, giới hạn endpoint Admin | Có nền auth; cần kiểm tra trên bản ghép | Bảo/Vương |
| Chỉ truy cập phiên chat/dữ liệu sử dụng của mình | Có kiểm tra session; report cần bổ sung | Vương/Bảo |

## 2. Quản lý phiên chat

| Tính năng | Hiện trạng source | Người chính |
| --- | --- | --- |
| Tạo phiên hỏi đáp | Có ở Vương | Vương |
| Danh sách phiên chat, tìm kiếm, phân trang | Có | Vương |
| Xem lịch sử tin nhắn và citations | Có | Vương |
| Gửi câu hỏi, nhận trả lời trong phiên | Có luồng gRPC; cần hoàn thiện API-only và reliability | Vương/Khôi |
| Xóa mềm phiên chat | Có | Vương |
| Retry request không tạo hai lượt chat/tính phí trùng | Cần bổ sung idempotency/state | Vương/Bảo |
| Hiển thị rõ trả lời, thiếu căn cứ, bị chặn hoặc lỗi dịch vụ | Có nền no-match/moderation; cần sửa error contract | Khôi/Vương |

Lưu lịch sử theo phiên đã có; suy luận follow-up dựa trên các lượt trước chưa có trong proto hiện tại (chỉ gửi prompt hiện tại). Hội thoại đa lượt có ngữ cảnh là hạng mục mở rộng đề xuất, chưa mặc định là requirement đã hoàn thành.

## 3. AI hỏi đáp luật giao thông qua API

| Tính năng | Hiện trạng source | Người chính |
| --- | --- | --- |
| Sinh câu trả lời tiếng Việt bằng Groq API | Yêu cầu mới; PRN hiện dùng Gemini tùy key hoặc local synthesis | Khôi |
| Tạo embedding câu hỏi/văn bản qua API | Có nền Gemini hoặc local fallback; cần API-only adapter/config | Khôi |
| Tìm đoạn luật liên quan trong Qdrant | Có nền retrieval | Khôi |
| Chỉ dùng chunk đã xác thực, còn hiệu lực, đúng ngày/version | Có cờ verified/active; cần ngày/version/recheck SQL | Khôi/Vương |
| Sinh câu trả lời dựa trên căn cứ được truy xuất | Có RAG nền; cần kiểm chứng chất lượng và API thật | Khôi |
| Trích dẫn tên/số văn bản, Điều/Khoản/Điểm, excerpt và URL | Có snapshot title/article/clause/URL; cần Điểm riêng và chunk FK/version | Khôi/Vương/Bảo |
| Từ chối trả lời pháp lý khi thiếu căn cứ xác minh | Có no-match; cần kiểm tra trên nguồn thật | Khôi |
| Moderation prompt vi phạm và trả trạng thái bị chặn | Có keyword moderation ban đầu | Khôi |
| Theo dõi provider/model, token usage thực, timeout/rate limit | Cần bổ sung; hiện tokens ước lượng | Khôi |
| API lỗi trả lỗi rõ; không tự chạy AI local | Yêu cầu mới; cần bỏ fallback local | Khôi/Vương |

Generation và embedding là hai adapter/config riêng. Model embedding mới phải dùng cùng không gian vector cho indexing/query; đổi model cần reindex, không chỉ đổi dimension. API AI không phải nguồn xác minh hiệu lực luật; nguồn và bằng chứng pháp lý vẫn là điều kiện bắt buộc.

## 4. Tra cứu, thu thập và cập nhật văn bản

| Tính năng | Hiện trạng source | Người chính |
| --- | --- | --- |
| Danh sách văn bản, tìm kiếm, phân trang, lọc hiệu lực | Có ở Phúc | Phúc |
| Lọc loại văn bản/trạng thái xử lý | Cần bổ sung đủ | Phúc |
| Xem chi tiết văn bản/nguồn/metadata | Có nền DTO/detail | Phúc |
| Xem các điều khoản và lịch sử xác thực | Cần bổ sung truy vấn/evidence/retention | Phúc/Bảo |
| Admin kích hoạt crawl từ thuvienphapluat.vn | Có trigger đồng bộ; cần durable job/status | Phúc |
| Crawl số hiệu thật, nội dung, metadata và bằng chứng hiệu lực | Hiện mới title/link + số hiệu hash; cần hoàn thiện | Phúc |
| Verification trạng thái Pending/Verified/Outdated và sửa đổi từng phần | Có registry/heuristic; cần nguồn thật và phạm vi chunk | Khôi/Phúc |
| Chunk theo Chương/Điều/Khoản/Điểm, giữ ID/hash/version | Có schema nền; pipeline crawler chưa nối | Phúc/Bảo |
| Embedding/upsert Qdrant, retry không nhân đôi | Có index RPC nền; cần nối SQL/workflow và API-only | Phúc/Khôi |
| Theo dõi pending/running/indexed/failed và thử lại | Cần bổ sung trạng thái/job recovery | Phúc/Bảo/Khánh |
| Vô hiệu hóa chunk cũ/hết hiệu lực ở SQL, Qdrant và cache | SQL có cron nền; phần đồng bộ còn thiếu | Phúc/Khôi |

Không mặc định có upload tài liệu tùy ý, CRUD sửa/xóa luật thủ công hay lấy nguồn ngoài thuvienphapluat.vn: endpoint bắt buộc hiện tại là list/detail/crawl-trigger. Muốn thêm thì ghi thành scope mới riêng.

## 5. Hạn ngạch, sự kiện và cảnh báo

| Tính năng | Hiện trạng source | Người chính |
| --- | --- | --- |
| Kiểm tra số dư trước inference, giữ chỗ quota khi có request đồng thời | Cần bổ sung | Bảo/Vương |
| Worker quyết toán quota theo usage/chính sách tính phí | Chưa tìm thấy Worker PRN thật | Bảo/Khánh |
| ChatCompletedEvent và DocumentUpdatedEvent qua Kafka | Chat event Redis đã có; Kafka/document event còn thiếu | Khánh |
| Event pending bền vững, retry sau broker outage | Cần bổ sung | Khánh/Bảo/Vương |
| Chống trừ quota trùng khi replay/restart | Cần bổ sung transaction/marker | Bảo/Khánh |
| Retry giới hạn, DLQ và replay phục hồi | Cần bổ sung | Khánh |
| Log vi phạm và email cảnh báo User/Admin | Có cờ moderation; Worker/email chưa có | Khánh |
| Email retry tách khỏi quota | Cần bổ sung; SMTP không được hứa exactly-once | Khánh |

Không có tính năng nạp tiền/thanh toán/mua gói trong requirement hiện tại. Token usage provider và quota nội bộ cần chính sách rõ; request timeout không chứng minh provider chưa phát sinh chi phí.

## 6. Cron và báo cáo

| Tính năng | Hiện trạng source | Người chính |
| --- | --- | --- |
| Chạy job lúc 00:00 múi giờ Việt Nam, phục hồi job bỏ lỡ | Có midnight job theo host; cần timezone/catch-up | Phúc/Khánh |
| Dọn phiên rỗng/quá hạn theo chính sách retention | Có nền xóa phiên rỗng; cần bảo vệ pending work | Phúc |
| Tái kiểm tra hiệu lực, đồng bộ luật mới hết hiệu lực | Có cập nhật SQL; cần verification và Qdrant/cache | Phúc/Khôi |
| Báo cáo lượt hỏi/token theo user và khoảng ngày | Cần Usage API | Bảo |
| Tổng hợp ngày, xuất file/log, gửi báo cáo khi cấu hình được bật | Cần nối report service và job | Phúc/Khánh |

Không thêm bảng UsageReports/ViolationLogs. Thống kê từ ChatMessages/ChatSessions; evidence/log có retention riêng.

## 7. Vận hành, giám sát và tích hợp

| Tính năng | Hiện trạng source | Người chính |
| --- | --- | --- |
| REST API/Swagger cho React/mobile/Postman, JWT và ProblemDetails | Có nền REST/Swagger; chưa có frontend mới trong scope này | Vương/Bảo |
| Gateway định tuyến, rate limit, trace | Có trong ảnh C1; chưa có host riêng | Vương |
| Redis cache và vô hiệu hóa cache theo document version/event | Có trong ảnh C1; cần triển khai theo scope cache đã chốt | Vương/Phúc |
| File log JSON có rotation, volume, masking | Cần triển khai xuyên dịch vụ | Cả nhóm |
| Metrics HTTP/gRPC/AI và Kafka publish/receive/process/retry/error/duplicate | Cần bổ sung | Mỗi người module mình |
| Theo dõi service health, Worker heartbeat và consumer lag | Cần bổ sung | Khánh/Vương |
| Truy vết Gateway → REST → gRPC → Kafka → Worker | Cần bổ sung | Cả nhóm, Vương tích hợp |
| Grafana dashboard/alerts, Prometheus/Loki/Tempo/Alloy | Cần bổ sung stack/provisioning | Vương |
| Docker Compose chạy Gateway, REST, gRPC, Worker, DB, broker và monitoring | Có Compose ban đầu; Worker echo/Redis broker cần thay | Vương/Khánh |
| Secrets qua môi trường/user-secrets, health/readiness và dữ liệu bền vững | Có nền config; cần hoàn thiện deployment | Vương/Bảo |
| Demo mất broker, Worker restart, replay event, provider lỗi và luật hết hiệu lực | Cần chạy trên bản ghép | Cả nhóm |

## 8. Bổ sung đã được người dùng yêu cầu: chat ảnh và học/luyện thi

Scope mới gồm chatbot giải thích ảnh câu hỏi/biển báo/sa hình, học theo ngân hàng câu hỏi và bộ đề, chọn N câu/range/chủ đề, trộn câu/phương án an toàn, đề sẵn/đề ngẫu nhiên, thi thử có timer và chấm server, xem lại/ôn sai/bookmark/tiến độ, Admin import/publish bank có nguồn/version. Đây là phần cần xây, chưa được khảo sát là đã có ở các nhánh PRN.

Chi tiết toàn bộ tính năng, luồng, API, dữ liệu và phân công mở rộng nằm ở LEARNING-AND-IMAGE-CHAT-PLAN.md. Vision/OCR cũng dùng API; đáp án chuẩn và luật chấm lấy từ bank/profile đã xác minh, không do AI quyết định. Số câu mỗi bank/đề và cấu trúc thi là config theo nguồn/profile, không hard-code một số cho mọi hạng bằng.

Tính năng follow-up có context ảnh/câu hỏi nay nằm trong scope mở rộng này; proto và persistence cần bổ sung. Ràng buộc SQL 7 bảng core vẫn phải được xử lý rõ trong thiết kế dữ liệu học/thi, chưa có migration mở rộng nào được tạo.

Cập nhật plan hợp nhất: đề xuất React/TypeScript tại web/ cho UI tài khoản/tiến độ, chat chữ/ảnh, học, thi/kết quả và Admin nội dung; task UI đã được chia ở task.md và IMPLEMENTATION-PLAN.md. Đây là việc cần xây, chưa có source UI mới. Giọng nói, tư vấn môn học/điểm số FLM, Obsidian graph, thanh toán hoặc quên mật khẩu chưa nằm trong scope. Không chuyển tính năng FLM thành tính năng PRN chỉ vì cùng repository.

Đọc TEAM-REMAINING-WORK-PLAN.md để chia việc song song và CODE-DESIGN-PLAN.md để xem contract/luồng dữ liệu. Tài liệu này là danh mục chức năng đích và trạng thái source; không tuyên bố toàn bộ đã triển khai hoặc chạy thực tế.
