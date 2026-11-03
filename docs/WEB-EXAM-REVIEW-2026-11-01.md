# Xem lại bài làm và mở mô phỏng trên web — 01/11/2026

Cập nhật tiếp theo: **đã chuẩn hóa/nhập 115 câu và 6 đề luyện vào DB local riêng, kiểm browser với API thật**. Xem [LOCAL-LEARNING-115-2026-11-01.md](LOCAL-LEARNING-115-2026-11-01.md). Các mục còn thiếu bank bên dưới mô tả trạng thái trước lượt nối dữ liệu này; hosting HTTPS bên ngoài vẫn chưa triển khai.

Ưu tiên web, điện thoại để sau. Thay đổi local trên `codex/prn-c2-integration-local`, HEAD `dbdcb5f`; không commit/push/PR/merge/deploy. Giữ các thay đổi C2/animation đã có trước lượt này. Không thay schema hoặc tạo migration.

## Luồng đã nối

- Nộp bài thành công (bao gồm đường gọi nộp khi hết giờ) chuyển sang `/ket-qua/:attemptId`. Không cần đọc Redis thêm sau khi nộp thành công.
- Đề đã nộp được tiếp tục bằng mã đề có nút **Xem lại từng câu**; `AttemptId` chỉ có giá trị khi trạng thái Redis là `Submitted`.
- **Tiến độ học → ngân hàng → Lịch sử → Xem bài làm** mở cùng màn hình. Ngân hàng và tab nằm trong query string; Quay lại trở về đúng mục lịch sử.
- Hiển thị điểm/đạt, số câu sai/chưa trả lời, thời điểm nộp giờ Việt Nam, phiên bản bank; từng câu có ảnh, lựa chọn đã chọn, đáp án đúng, lời giải và nút **Xem mô phỏng 3D** nếu có URL hợp lệ.
- Có lọc tất cả/sai/chưa trả lời, giữ số thứ tự câu trong đề. Lỗi tải kết quả có Thử lại; thiếu lời giải/mô phỏng có thông báo riêng.

## Dữ liệu và quyền xem

`GET /api/exam-attempts/{id}/review` dùng `ExamResultService.GetReviewAsync`: kiểm owner từ JWT, đọc snapshot đã nộp trong User SQL; trả DTO rõ kiểu thay vì để web tự parse chuỗi JSON của entity. Không đọc bank hiện tại và không phụ thuộc Redis/Content service. Đổi/ngừng bank sau này không thay nội dung đã lưu.

URL từ snapshot được kiểm lại theo `Content:AnimationAllowedHosts` trên User host; web tiếp tục kiểm HTTPS/exact host và mở tab mới với `noopener noreferrer`. Cần cấu hình cùng host runtime với Content host. Không gửi đáp án/lời giải/URL trong active-exam DTO. API cũ `/api/exam-attempts/{id}` vẫn giữ nguyên để tương thích.

Snapshot cũ không có URL vẫn không có mô phỏng; không tự ghép số thứ tự câu vào URL, không sửa lịch sử cũ theo bank mới.

## Chuẩn bị gắn đúng bank/version

Database local `TrafficContent_C2_MergedVerify_20261030` được kiểm tra chỉ có một bank kiểm thử, version 1, một câu số 1. Không có bank thật 486–600 trong DB này; không thể nhận diện 115 GUID đích từ số câu trong animation. Không ghi DB dùng chung.

`scripts/prepare-animation-links.py` nhận **ContentBank JSON camelCase trước import**, bank GUID/version đích và base URL HTTPS. Công cụ đối chiếu đủ 115 câu với `bank-review/bank.json`: nội dung, thứ tự phương án, ánh xạ đáp án theo ID phương án, SHA-256 ảnh; kiểm scenes khớp SHA bản đã duyệt. Thiếu câu, trùng GUID/số câu, sai bank/version hoặc khác dữ liệu thì dừng. Không tạo GUID câu từ số câu.

Ví dụ sau khi có bank và hosting thật:

```powershell
python scripts/prepare-animation-links.py --bank '<ContentBank.json>' --bank-id '<bank GUID>' --version '<revision>' --base-url 'https://<host-runtime>/' --output '<manifest-preview.json>'
```

Đầu ra `{bank, animations}` dùng với màn hình kiểm tra nội dung/admin hiện có; script chỉ tạo file mới, không gọi import/publish/SQL. Đây là đối chiếu với nguồn mô phỏng đã duyệt, không phải xác minh pháp luật độc lập hoặc kiểm tra hosting online. Bank đã import là immutable: khi đổi nội dung/URL, tuân thủ quy trình bank version và GUID mới của `QuestionBankService`; không cập nhật thẳng bản đã xuất bản.

## Bằng chứng kiểm tra

| Kiểm tra | Kết quả và giới hạn |
| --- | --- |
| `dotnet build ChatAIWeb.slnx --nologo -v quiet` | Qua, 0 warning/error |
| `dotnet test BusinessLogic.Tests/BusinessLogic.Tests.csproj --nologo -v quiet` | 15 qua, 0 bỏ qua; gồm 6 ca review mới cho snapshot/owner/URL |
| C2 integration với SQL Server, Redis, Kafka thật | 1 qua, 0 bỏ qua; hai DB test tạo mới riêng và xóa sau test. Kiểm API review mới sau xóa Redis, đúng bank/version/đáp án/lời giải/URL, khác owner trả 404. Nội dung là fixture giả lập, không phải ngân hàng thật. TRX: `artifacts/test-results/exam-review-c2.trx` |
| `python -m unittest discover -s tests -p test_prepare_animation_links.py -v` | 6 qua; không đổi bank đầu vào, chặn sai identity/nội dung/đáp án/ảnh/thứ tự/URL/trùng câu/chưa duyệt |
| `node --test tests/content-animation.test.mjs` | 4 qua |
| `npm run build` trong `web` | Qua TypeScript và Vite |
| Browser web | Fixture API riêng qua Playwright; tạo đề, xác nhận lúc làm chưa có lời giải/link, nộp → lỗi review HTTP 503 chủ động → Thử lại thành công, đủ đúng/sai/chưa trả lời, thứ tự đáp án, ảnh gốc, bộ lọc, chặn link sai, xem từ lịch sử và Quay lại giữ tab/ngân hàng |
| Hiển thị | Xem ảnh 1440×1080, 1024×768, scale CSS 200%; không tràn ngang vùng review. Chưa kiểm điện thoại |
| Mở mô phỏng | Nút dùng đúng URL từ snapshot giả lập; test redirect riêng host giả lập về trang local câu 544, trang tải được và `window.opener === null`. Không phải bằng chứng URL HTTPS đã deploy |

Scripts browser: `output/playwright/setup-exam-review.cjs`, `check-exam-review.cjs`, `check-exam-review-navigation.cjs`; log `tmp/exam-review-browser-check.log`, `tmp/exam-review-navigation.log`. Ảnh: `output/playwright/exam-review-question.png`, `exam-review-desktop.png`, `exam-review-1024.png`, `exam-review-zoom200.png`. Một lỗi 503 được chủ động tạo để kiểm Thử lại; một cấu hình route mock quá rộng ban đầu đã được sửa trước khi kiểm tra thành công. Không coi fixture UI là kiểm tra backend thật.

115 scenes/renderer/model không sửa. SHA-256 scenes vẫn `60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9`. Không chạy lại 47 test renderer vì không đổi phần đó; lần này chỉ chạy 4 test contract animation liên quan.

## Phần chưa hoàn tất

1. Cần bank thật có GUID/version và ảnh khớp nguồn 115 cảnh để tạo manifest gắn URL. Chưa tạo manifest thật, import hoặc publish dữ liệu.
2. Cần hosting HTTPS chứa bản learner đã duyệt. Chưa deploy. Không dùng localhost để phát hành.
3. Cần chạy trọn luồng trình duyệt qua Gateway với bank thật và hosting thật. API integration đã qua trên fixture riêng; kiểm UI dùng response giả lập.
4. Kiểm điện thoại và các giới hạn C2/AI/deployment khác vẫn theo báo cáo trước, không được mở rộng thành đã nghiệm thu.

Docker Desktop được khởi động để chạy Redis/Kafka test; Vite local chạy cổng 5173. Không dừng server mô phỏng cổng 8765 đã có trước.
