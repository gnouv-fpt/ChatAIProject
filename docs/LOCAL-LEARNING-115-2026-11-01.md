# Ngân hàng 115 câu và luồng web local — 01/11/2026

**Cập nhật tiếp theo:** đã thêm gói luyện tập 600 câu độc lập và sáu đề mới, bảo toàn gói 115 câu/sáu đề trong báo cáo này. Trạng thái hiện tại, nguồn, phiên bản và lệnh chạy lại: [bàn giao ngân hàng 600 câu](LOCAL-QUESTION-BANK-600-2026-11-01.md). Số liệu bên dưới ghi lại thời điểm chỉ có gói 115 câu.

Đã đưa 115 câu nguồn 486–600 vào Content SQL local, tạo 6 đề luyện và chạy trọn luồng web qua Gateway với dữ liệu nguồn thực của bộ mô phỏng. Đây là bộ luyện sa hình local từ PDF đã dùng để duyệt mô phỏng, không phải bộ đề chuẩn GPLX hoặc xác minh pháp luật độc lập. Không có dữ liệu 1–485 trong gói này.

## Mở dùng thử

Mở **http://127.0.0.1:18080/hoc**, đăng ký tài khoản mới hoặc đăng nhập tài khoản đã tạo trong stack này. Chọn **Sa hình 486–600 · 115 câu luyện tập local**. Có thể chọn số câu tự luyện, hoặc sang Luyện thi chọn một trong sáu đề mẫu. Tài khoản ở database khác không tự được chuyển sang đây.

Ảnh và mô phỏng dùng máy chủ có sẵn `http://localhost:8765`. Kết quả sau nộp có đáp án/lời giải và nút mở đúng câu; lúc đang làm không có lời giải. Lịch sử và câu sai hiện trong Tiến độ học.

## Dữ liệu đã nhập

| Thành phần | Giá trị đã kiểm tra |
| --- | --- |
| SQL User riêng | `TrafficUser_WebLearning_57e824ae` |
| SQL Content riêng | `TrafficContent_WebLearning_57e824ae` |
| Bank GUID / version | `aeabe38b-f3c7-5d52-82e6-0214b3b6d37c` / `1` |
| Câu hỏi | 115/115 đã bật cho học trong DB local; 115 có URL mô phỏng |
| Đề mẫu | 6/6 đã bật trong DB local; nhóm 486–505, 506–525, 526–545, 546–565, 566–585, 586–600 |
| Mục tiêu tự luyện | 80%; mặc định 20 câu/20 phút, 16 câu đúng. Đề cuối 15 câu/15 phút, 12 câu đúng. Không áp quy tắc điểm liệt vì nguồn trích không có metadata đó |
| Package hash do Content API trả | `1CA6EAF8B7D0363F6610AEB87A289BD77D1B9E280F3902E15E9A01CB0787DF8F` |
| Redis riêng | Redis test `localhost:16379`, database index `3` |
| Kafka topic riêng | `local-learning-exam-submitted-v1`, DLQ `local-learning-exam-submitted-dlq-v1` |

`build-local-learning-bank.py` đối chiếu SHA-256 scenes, JSON duyệt và từng ảnh nguồn; kiểm đủ số câu/revision/đáp án. GUID gắn với toàn bộ identity của gói nguồn/release/URL/version/chính sách luyện và nội dung từng câu, không dùng số câu làm khóa DB. Chạy lại cùng gói giữ GUID; đổi URL/version/nội dung phải tạo identity mới, không ghi đè bank đã nhập.

Lời giải gồm đáp án theo phương án gạch chân của PDF và diễn giải từ các bước mô phỏng đã duyệt; không tự thêm căn cứ pháp luật mới. Không sửa scenes, renderer, model hay revision đã duyệt. SHA-256 scenes giữ nguyên `60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9`.

Importer dùng API admin hiện có: import → kiểm errors/hash → bật bank local → import/bật templates. Đã chạy lại importer, không tạo trùng hoặc đổi hash. Database trước đó `TrafficContent_C2_MergedVerify_20261030` được giữ nguyên; các migrations có sẵn chỉ được apply bằng lệnh explicit vào hai DB riêng nói trên. Không tạo/sửa migration hoặc shared schema.

## Chạy lại / dừng

```powershell
# Docker Desktop và SQL instance .\MSSQLSERVER_VUON phải sẵn sàng.
pwsh -File scripts/start-c2-test-infrastructure.ps1
pwsh -File scripts/start-local-learning.ps1
pwsh -File scripts/import-local-learning.ps1

# Chỉ dừng các process do launcher ghi nhận, giữ DB và Redis:
pwsh -File scripts/start-local-learning.ps1 -Stop
```

Không chạy start khi stack đã bật; nếu cần build lại, dừng bằng `-Stop` trước rồi start. Launcher không dừng process đang chiếm cổng của ứng dụng khác. Các host riêng: Gateway 18080, User 15039, Content 15040, Vite 15173. Server mô phỏng 8765 có trước vẫn giữ nguyên. Topic được tạo trước Worker để tránh lỗi topic chưa tồn tại lúc khởi động.

Secrets và tài khoản test chỉ nằm trong `artifacts/local-learning/` đã bị Git ignore; không đưa runtime.json hoặc các file account vào Git. Người dùng có thể đăng ký tài khoản riêng qua web, không cần tài khoản admin để học/thi.

## Hỗ trợ URL local có giới hạn

Host chỉ đọc `Content:LocalAssetOrigin` trong môi trường **Development**. Giá trị đang dùng là `http://localhost:8765`. Bank/manifest/review chỉ cho phép đúng origin loopback đó, không query/fragment/credentials/traversal. Cấu hình này không nhận từ bank import; mặc định không bật. Ngoài Development, import/review animation tiếp tục cần HTTPS và host được cấu hình. Frontend dùng đúng origin do API review trả, không tự mở mọi URL localhost.

Database local chứa URL loopback nên không phải dữ liệu để đưa thẳng lên production. Khi triển khai cần hosting HTTPS và gói/version phù hợp; chưa deploy hoặc thay trust certificate của máy.

Custom exam hiện giữ tỷ lệ mục tiêu của profile khi chọn N khác mặc định, làm tròn lên: bộ này chọn 5 câu thì mục tiêu 4/5. Đề mẫu giữ đúng ngưỡng của từng template. UI thi hiển thị mục tiêu trước khi nộp.

## Kiểm tra đã thực hiện

- Build Presentation, ApiGateway, WorkerService và `npm run build` trong web: qua.
- Content.Tests: **58 qua**; BusinessLogic.Tests: **15 qua**; C2.Integration.Tests: **1 qua**, không bỏ qua. Integration dùng SQL/Redis/Kafka thật trong DB fixture tách riêng, không dùng bank local này thay fixture.
- Python `test_local_learning_bank.py`: **4 qua**; Node `tests/content-animation.test.mjs`: **5 qua**. Kiểm phủ đủ câu, identity ổn định, phạm vi đề, tỷ lệ điểm, URL mặc định bị chặn và exact local origin khi được cấu hình.
- `scripts/check-local-learning.py` gọi Gateway thật: 115 câu từ SQL; tải cả 115 nhóm ảnh và đối chiếu SHA; 115 URL HTML đúng số câu; 6 đề; active DTO không lộ key/lời giải; autosave; kết quả có đúng/sai/chưa làm; nộp trùng không tạo attempt mới; tài khoản khác bị chặn; xóa đúng key đề test đã nộp trong Redis DB 3 rồi vẫn đọc review SQL được; history/notification có kết quả; thứ tự đề mẫu đúng.
- `--finish-timeout`: đợi hết đúng một phút của đề một câu không trả lời; Worker tự nộp và review SQL có 0/1, câu chưa trả lời. Không tua đồng hồ hoặc sửa deadline Redis cho kiểm tra này.
- Redis có inbox event của lượt browser `c5317184-20b5-411b-b555-9cb8292567bc`, xác nhận consumer Kafka đã ghi inbox, bên cạnh API notification có SQL fallback.
- Browser qua Gateway thật, không giả lập business API: học → chọn 3 câu → tạo đề → autosave → rời trang → resume giữ deadline/answers → trả lời tiếp → nộp → review **1/3**, đủ đúng/sai/chưa trả lời → mở thực trang câu **550**, phát/dừng/bước sau/ảnh gốc/3D → lịch sử → Quay lại giữ bank/tab. Kiểm chiều rộng 1440 và 1024; không lỗi JavaScript trong lượt xác minh riêng.
- Browser đề mẫu 526–545: tạo đủ 20 câu, ngưỡng 16, lưu câu 544, nộp ra 1/20, review có URL đúng `q544.html` và trang learner thực tải được. Không dùng redirect giả lập như lượt kiểm tra UI trước đây.
- Đã xem ảnh thư viện, review và tiến độ; ảnh kết quả/learner nằm trong `output/playwright/local-learning-*.png`. Không kiểm điện thoại.

Một lượt browser đầu có trạng thái trả lời khác dự kiến nên không dùng làm bằng chứng đạt; lượt xác minh riêng tạo bài mới và kiểm số câu đã lưu 0 → 1 → 2 trước khi nộp. Script API ban đầu kỳ vọng register trả 200 thay vì 201, đã sửa expectation và loại bỏ ghi response body khi báo lỗi. Worker từng log topic chưa có trước lần publish đầu; inbox hiện đã nhận, launcher đã bổ sung tạo topic trước Worker.

Bằng chứng máy đọc được: `artifacts/local-learning/import-result.json`, `live-check.json`, `proof-browser-check.log`, `template-browser-check.log`; TRX integration `artifacts/test-results/local-learning-c2.trx`. Scripts browser trong `output/playwright/`.

## Phạm vi còn lại

- Bổ sung câu 1–485 nếu cần đủ bộ 600; cấu hình bộ đề chuẩn/hạng GPLX và metadata điểm liệt theo nguồn được kiểm tra, thay vì coi mục tiêu 80% local là quy tắc thi chính thức.
- Hosting HTTPS/deployment, kiểm ngoài máy và điện thoại để sau. Chưa deploy, push, PR hoặc merge.
- Các phần AI/RAG, bookmark C2 và giới hạn hạ tầng trong báo cáo C2 trước không tự được coi là hoàn thành bởi luồng luyện sa hình này.

Git vẫn `codex/prn-c2-integration-local`, HEAD `dbdcb5f`; thay đổi source và artifact mới đều local, chưa commit. Giữ nguyên các chỉnh sửa C2/animation có sẵn.
