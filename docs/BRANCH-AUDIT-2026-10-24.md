# Kiểm tra các nhánh PRN của team — 24/10/2026

Đã `git fetch origin --prune` và đối chiếu danh sách branch trực tiếp bằng `git ls-remote --heads`. Khảo sát source bằng git show/diff/ls-tree; không checkout, merge, commit hay push. Build từ bản git archive của từng commit trong thư mục TEMP riêng, không chạy API/migration.

## 1. Code tìm được

| Thành viên | Nhánh remote | Commit | Code đã có | Build .NET lần kiểm tra này |
| --- | --- | --- | --- | --- |
| Bảo | PRN-BAO-dev | 6d79f16 | 4 projects/layers, entities/DbContext/migration, repositories, JWT/auth/refresh-token | PASS, 0 warning/error |
| Khôi | PRN-KHOI-dev | 7084b1f | Python gRPC, moderation, verification, embedding, Qdrant/RAG, seed, client_test.py, proto và .NET gRPC client | PASS, 0 warning/error |
| Vương | PRN-VUONG-dev | 0796c1f | Auth nền Bảo, Chat API/service/repos, .NET gRPC client, Redis publisher, Dockerfiles/Compose, Python/proto của Khôi | PASS, 0 warning/error |
| Phúc | PRN-PHUC-dev | 1ab5e75 | DocumentsController, DTO/service/repository, crawler, MidnightCleanupJob và DI | PASS, 0 warning/error |
| Khánh | Không thấy PRN-KHANH-* trên origin | — | Chưa xác định được code Worker/Kafka cho bài PRN trong các ref đã tìm | Chưa có nhánh để build |

PRN-dev và PRN-main vẫn ở f178699 (Initial commit, ứng dụng Razor/course cũ); chưa tập hợp phần PRN mới. HEAD đang mở khớp origin/PRN-VUONG-dev, ngoài các thay đổi chưa commit của workspace.

Đã kiểm tra tên file trên các nhánh Khanh-v7, akkhanh05, FastAPI-RAG-Backend-Khanh: thấy code ứng dụng course/RAG cũ, không thấy project Worker/Kafka/email consumer PRN theo các tên file liên quan. Điều này không chứng minh Khánh chưa làm; code có thể chưa push hoặc nằm ở repo/ref khác chưa được cung cấp.

Bổ sung khi người dùng chỉ định FastAPI-RAG-Backend-Khanh: đã đọc backend/README.md, app/main.py, chat endpoint, rag_engine.py, vector_store.py và requirements.txt tại cc003f6. Xác nhận đây là FastAPI FLM/Curriculum & Syllabus, parser đọc vault môn học; không phải phần Kafka/Worker của PRN. Tìm source toàn nhánh theo ChatCompletedEvent/TrafficRagInference/Kafka/MailKit/thuvienphapluat không thấy các thành phần PRN đó; BackgroundService có sẵn thuộc RagasEvaluationBackgroundService của ứng dụng cũ. Plan chia phần còn thiếu cho 5 người: TEAM-REMAINING-WORK-PLAN.md.

## 2. Những phần phải hoàn thiện khi tích hợp

### Bảo

- Nhánh Bảo là ancestor của cả ba nhánh thành viên còn lại, nên không cần viết lại auth hay merge riêng nền này lần nữa.
- Các remote vẫn chứa UsageReport/ViolationLog và migration cũ. Scope 7 bảng đã chỉnh trong working tree hiện tại; khi ghép code phải giữ thay đổi này, không phục hồi hai bảng ngoài yêu cầu.

### Khôi và Vương

- So sánh Protos/chat_inference.proto và toàn bộ grpc_inference_service giữa hai nhánh cho kết quả giống nhau. Code Python của Khôi đã nằm trong snapshot nhánh Vương, dù lịch sử không phải merge branch Khôi.
- .NET GrpcDtos/IGrpcInferenceService/GrpcInferenceService được thêm ở cả hai nhánh và có khác biệt. Nhánh Vương có bắt RpcException trả fallback; cần hợp nhất theo contract/error handling đã chốt.
- Verification vẫn là registry tĩnh/heuristic; Qdrant có fallback RAM và embedding có fallback hashing; chưa phải bằng chứng pipeline dữ liệu nguồn đã được xác minh.
- Citation proto thiếu chunk ID; ChatbotService lưu snapshot nhưng chưa gắn DocumentChunkId, chưa kiểm tra quota trước inference.
- RedisEventPublisher hiện có nhánh publish mô phỏng khi chưa cấu hình; requirement mới yêu cầu Kafka thật.
- Compose có Worker dùng runtime image + echo placeholder; chưa có consumer/quota/email thật trong nhánh này.

### Phúc

- Documents API list/detail, paging/search/IsActive và Admin crawl-trigger đã có, DI đã đăng ký.
- Crawler tải trang danh sách, lấy title/link và lưu LegalDocuments Pending; DocumentNumber hiện tạo dạng CRAWL-<hash>. Chưa lấy đầy đủ nội dung văn bản/số hiệu thật, chưa tạo DocumentChunks, chưa gọi VerifyLegalDocument/IndexDocument và chưa phát document event.
- Nếu selector không khớp thì crawler return mà không báo số lượng/lỗi parsing. Crawl-trigger await toàn bộ crawl rồi mới trả 202; chưa có durable background job.
- Crawler đang dùng DbContext trực tiếp trong BusinessLogic, cần đưa truy vấn/persistence qua repository theo quy tắc project.
- MidnightCleanupJob đang nằm trong Presentation, truy vấn EF và chứa quyết định nghiệp vụ; cần đưa nghiệp vụ vào BusinessLogic/repository và host lịch vào Worker.
- Cron dọn session rỗng hơn một ngày và cập nhật SQL document hết hiệu lực; chưa đồng bộ Qdrant/cache, chưa tổng hợp daily report. Lịch dùng DateTime.Now/Today theo host, cần múi giờ cấu hình rõ.
- Controller detail trả NotFound trực tiếp; khi chuẩn hóa cần thống nhất exception/ProblemDetails. Filter chưa có DocumentType theo yêu cầu.

## 3. Kiểm tra ghép nhánh không thay đổi checkout

Dùng `git merge-tree --write-tree` để tính kết quả merge trong object database, không cập nhật index/working tree:

- Vương + Phúc: xung đột Presentation/Program.cs. BusinessLogic.csproj tự ghép được ở lần kiểm tra này. Cần giữ đồng thời DI auth/chat/gRPC/broker và document/crawler/job; sau đó build lại bản tích hợp.
- Vương + Khôi: xung đột BusinessLogic.csproj, GrpcDtos.cs, GrpcInferenceService.cs, IGrpcInferenceService.cs và task.md. Không cần merge trọn nhánh chỉ để lấy Python/proto vốn đã giống nhau.

## 4. Plan điều chỉnh

1. Dùng code Vương hiện có làm nền tích hợp, giữ các sửa đổi scope 7 bảng đang chưa commit.
2. Ghép phần Phúc, giải quyết Program.cs và packages; không viết mới Documents API/crawler/cron từ đầu.
3. Hợp nhất contract và error handling gRPC; giữ phần Python dùng chung, hoàn thiện verification/indexing và citation mapping.
4. Xác định ref chứa phần Khánh nếu có; nếu chưa có thì đây là phần cần triển khai: Kafka producer/consumer, Worker quota/email, retry/dedupe.
5. Nối crawler → verify → chunk SQL → index Qdrant; đưa cron về Worker và đồng bộ văn bản hết hiệu lực.
6. Hoàn thiện Gateway/cache và observability theo ảnh C1/requirement mới, kiểm thử runtime end-to-end.

## 5. Giới hạn bằng chứng

Build thành công chỉ xác nhận compile .NET của từng nhánh độc lập. Chưa chạy Python client_test, crawler với trang thật, SQL/Kafka/Qdrant/SMTP hoặc Compose end-to-end. Chưa merge code thực tế. Không dùng kết quả ghi trong progress của thành viên làm kết quả runtime đã tự kiểm chứng.
