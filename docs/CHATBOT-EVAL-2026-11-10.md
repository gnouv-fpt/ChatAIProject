# Kiểm thử chatbot giao thông — 10/11/2026

## Phạm vi và nguồn

- Chạy app .NET 8 qua Gateway 18080 → User SQL → Content SQL → gRPC AI 15052 → Qdrant thử nghiệm. Các DB, collection và tài khoản thử nghiệm tách khỏi môi trường dùng thật. Khóa API chỉ nằm trong `.env`/biến môi trường bị Git bỏ qua.
- Đáp án trắc nghiệm đối chiếu với PDF 600 câu CSGT đã công bố, gói `content-bank/csgt-2025-B-current/package.json` có hash nguồn; PDF này là nguồn **đáp án đề**, không phải căn cứ luật.
- Căn cứ luật đối chiếu với [VBHN 55/2026](https://vanban.chinhphu.vn/?classid=0&docid=217295&pageid=27160), [NĐ 168/2024](https://vanban.chinhphu.vn/?classid=1&docid=212167&pageid=27160), [NĐ 238/2026](https://vanban.chinhphu.vn/?classid=0&docid=218613&pageid=27160), và [TT 51/2024 ban hành QCVN 41](https://vanban.chinhphu.vn/?classid=1&docid=211908&orggroupid=4&pageid=27160). NĐ 238 có hiệu lực chung 15/08/2026; quy chuẩn QCVN 41:2026 tìm thấy mới ở dạng dự thảo ngày 22/09/2026, chưa coi là văn bản có hiệu lực.

## Thay đổi đã kiểm chứng

1. Bộ ghép ảnh nguồn hiện gồm **317 câu một ảnh** trong 600 câu (184 biển báo, 115 sa hình, 11 kỹ thuật, 5 nghiệp vụ lái, 2 quy tắc). 317/317 ảnh gốc qua gRPC thật trả `PracticeAnswered` đúng đáp án PDF, 0 token và 0 trích dẫn luật giả. 316/317 ảnh nén/thu nhỏ qua kiểm tra offline khớp đúng; ảnh câu 428 không đủ chắc được từ chối. Mười câu biển báo trước đây từng bị AI dẫn sai Điều 11 chung đều trả đúng nguồn đề, không gắn điều luật sai. Kết quả: `artifacts/local-ai/all-published-visual-live-2026-11-10.json`, `held-out-vision-bank-after-2026-11-10.json`.
2. `ChatbotService` và bộ ghép ảnh gRPC kiểm tra **ý định câu hỏi** trước khi dùng đáp án đề, kể cả có số câu. Ví dụ “Câu 493 ảnh có mấy xe màu đỏ?” không còn bị trả đáp án thứ tự xe. Ảnh gốc câu 490, 493, 310 đã chạy qua Gateway + hai SQL và được lưu lịch sử, trả đúng đáp án nguồn, 0 trích dẫn luật giả: `artifacts/local-ai/gateway-visual-eval.json`.
3. Với câu chữ, bộ sinh bắt buộc dẫn Điều 57 (phân hạng) và Điều 59 (tuổi) cho câu hỏi ghép A1/B/C1. Câu 119 trước sửa `NoMatch` vì top-5 Qdrant thiếu Điều 57 khoản 1 điểm a; nay truy xuất đúng các đoạn đã xác thực của cùng văn bản. Các câu xử phạt ghép sự kiện bắt buộc dẫn đủ điểm hành vi, khoản tiền phạt và điểm tước GPLX, hoặc đủ căn cứ người lái/người ngồi sau. Bộ kiểm thử Gateway tám câu **23, 25, 75, 56, 118, 119, 140, 141** đạt **8/8 trong hai vòng**: đúng phương án, đủ vị trí Điều/Khoản/Điểm bắt buộc và URL, có chunk ID thật. Kết quả: `artifacts/local-ai/gateway-bank-grounded-final-1-2026-11-10.json`, `gateway-bank-grounded-final-2-2026-11-10.json`.
4. Gói hợp nhất 55 điều NĐ 168 + 238 vẫn `Pending`: mã xác thực không cho kích hoạt toàn bộ chỉ vì hash đúng. Gói hẹp 13 đoạn Điều 6, 7, 12 được kiểm tra nội dung trùng nguyên văn NĐ 168 cũ, không đổi theo bản 238, có hash ghim tại `content-bank/legal/168-238-targeted-sanctions-reviewed.json`. Môi trường thử nghiệm đã nhập 16 chunk (kể cả 3 tiêu đề điều), xác thực và lập chỉ mục 16/16. Chỉ gói hẹp này dùng cho các câu 23/25/75; mọi chế tài chưa duyệt vẫn `NoMatch`.
5. Khi ảnh biển báo ngoài bộ đề không có mục QCVN tương ứng đã xác thực, gRPC trả `NoMatch` và giải thích rõ lý do. Hai ảnh biển P.101/P.102 lấy từ trang 80 PDF QCVN chính thức đều trả `NoMatch`, 0 trích dẫn bịa: `artifacts/local-ai/official-novel-sign-eval-2026-11-10.json`.

## Cổng kiểm thử

- Python gRPC unit: **57/57 passed** trong Docker.
- .NET `ChatAIWeb.Tests` với SQL Server tách riêng: **68/68 passed**. `Content.Tests`: **68/68 passed** ở vòng trước.
- Kho luật thử nghiệm VBHN 55: **113/113** chunk SQL/Qdrant khớp ID, nội dung hash, vị trí điều/khoản/điểm và URL; `artifacts/local-ai/integration-law-parity.json`.
- Phạm vi xử phạt hẹp: **16/16** chunk verified ở Content SQL và Qdrant cùng document ID; `artifacts/local-ai/targeted-sanction-parity-2026-11-10.json`.
- Một vòng Gateway trung gian gặp **HTTP 503 ở ca thứ bảy**, cùng thời điểm Groq trả 429 và token balance của tài khoản thử xuống còn 1.613, thấp hơn budget cần cho ngữ cảnh. Đã nạp lại quota **chỉ trong DB thử nghiệm**, chạy lại chậm hơn và đạt 8/8. Bộ đánh giá đã được sửa để lưu từng ca ngay và ghi HTTP lỗi. Dịch vụ gRPC nay báo `RESOURCE_EXHAUSTED` cho thiếu budget ngữ cảnh; adapter đổi thành HTTP 429 với thông báo quota rõ ràng. Đây không phải bằng chứng rằng Groq sẽ không còn 429 khi tải cao.

## Chưa đạt để tuyên bố ổn hoàn toàn

- Ảnh biển báo/sa hình mới ngoài 600 câu vẫn cần kho QCVN 41 và tập ảnh chuẩn độc lập để đo độ chính xác. Hai biển P.101/P.102 cho thấy hệ thống hiện **từ chối an toàn**, chưa trả được ý nghĩa biển dù văn bản nguồn có. Tập 317 câu chỉ chứng minh nhận ảnh của **bộ đề**, không chứng minh nhận diện mọi ảnh thực tế.
- `PracticeAnswered` dẫn nguồn đáp án PDF CSGT, chưa có trích dẫn điều luật riêng cho mỗi lời giải sa hình. Không thể tự gắn một điều luật chung để thay thế bằng chứng theo từng xe/hướng đi/biển.
- Mới duyệt một phạm vi xử phạt hẹp; phần còn lại của NĐ 168/238 có bảy ngoại lệ hiệu lực và phải rà soát từng phạm vi trước khi kích hoạt. Câu hỏi ngoài phạm vi này có thể trả `NoMatch`.
- API Groq có 429 trong chuỗi thử dày; cần chạy tiếp đánh giá lặp với quota đủ và quan sát tỷ lệ 503. Không thể hứa mọi câu hỏi đều có đáp án đúng chỉ từ các ca đã thử.
