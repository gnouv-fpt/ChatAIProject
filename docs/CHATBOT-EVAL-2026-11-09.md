# Kiểm thử chatbot và sa hình — 09/11/2026

## Phạm vi và nguồn bằng chứng

- Runtime gRPC Docker, Qdrant collection `prn232_live_test_20261109`, Gemini `gemini-3.6-flash` cho ảnh, Groq `openai/gpt-oss-120b` cho câu hỏi chữ.
- Kho thử nghiệm có 86 đoạn từ bản rà soát VBHN 55/2026: Điều 2, 10, 11, 12, 15, 22, 27, 57, 58, 59, 80. Đây chưa phải toàn bộ 975 đoạn của kho local trước đó.
- Đáp án chuẩn lấy từ `content-bank/csgt-2025/source-extraction.json`; bộ ca đối chiếu điều khoản lấy từ `content-bank/legal/rag-eval-source-cases.json`. Bản kết quả thô nằm tại `artifacts/local-ai/eval-results-2026-11-09.json` (được Git bỏ qua).
- Không lưu khóa API trong báo cáo.

## Câu hỏi chữ

12/12 ca trả đúng loại kết quả kỳ vọng: 9 ca `Answered`, 3 ca `NoMatch` (23, 25, 75, vì kho VBHN 55 không có mức xử phạt). 9/9 đáp án chọn được đối chiếu khớp đáp án gạch chân trong bộ 600 câu.

| Câu | Đáp án chuẩn | Kết quả | Căn cứ trả về | Nhận xét |
| --- | --- | --- | --- | --- |
| 2 | 2 | 2 | Điều 2 khoản 6 | Đạt |
| 23 | 3 | NoMatch | Không có | Đạt: hỏi chế tài ngoài kho |
| 25 | 3 | NoMatch | Không có | Đạt: hỏi chế tài ngoài kho |
| 34 | 2 | 2 | Điều 12 khoản 3 | Đạt |
| 56 | 4 | 4 | Điều 15 khoản 2 | Đạt |
| 75 | 4 | NoMatch | Không có | Đạt: hỏi chế tài ngoài kho |
| 118 | 1 | 1 | Ban đầu chỉ Điều 59 khoản 1 | Thiếu Điều 57; sau sửa prompt đã trả cả Điều 57 khoản 1 và Điều 59 khoản 1 |
| 119 | 3 | 3 | Ban đầu chỉ Điều 59 khoản 1 | Thiếu Điều 57; sau sửa prompt đã trả cả Điều 57 khoản 1 và Điều 59 khoản 1 |
| 125 | 1 | 1 | Điều 57 khoản 1 | Đạt |
| 140 | 2 | 2 | Điều 58 khoản 2 | Đạt |
| 141 | 2 | 2 | Điều 58 khoản 3 | Đạt |
| 194 | 4 | 4 | Điều 80 khoản 1 | Đạt |

## Ảnh sa hình

| Câu | Đáp án chuẩn | Kết quả quan sát được | Đánh giá |
| --- | --- | --- | --- |
| 490 | 3 | Chọn 3, dẫn Điều 22 khoản 2 | Đạt qua Gemini ảnh + sinh câu trả lời |
| 491 | 1 | Chọn 1, dẫn Điều 22 khoản 3 | Đạt qua Gemini ảnh + sinh câu trả lời |
| 492 | 2 | NoMatch; lần thử sau lỗi nhà cung cấp | Chưa đạt |
| 493 | 1 | Sau khi nạp Điều 27, chọn sai 2 và dẫn Điều 27 khoản 2 | **Sai thực tế**; đã thêm rule kiểm tra xe đã vào giao lộ, chưa xác nhận lại vì Gemini trả lỗi hạn mức |
| 494 | 2 | NoMatch trước khi nạp Điều 27; lần sau lỗi nhà cung cấp | Chưa đạt |
| 495 | 2 | Lỗi nhà cung cấp (429) | Chưa đánh giá được |

Ảnh thử là ảnh gốc trong `content-animations/bank-review/<số câu>/image-1.jpeg`, không phải ảnh tự tạo. Với câu 493, đáp án 1 được chứng minh bởi phần gạch chân trong PDF nguồn của bộ câu hỏi, trang 132, được lưu trong `content-bank/csgt-2025/package.json`.

## Lỗi tìm được và thay đổi

1. Gemini 2.5 trả 404 cho khóa mới. Đã chuyển model mặc định và launcher local sang Gemini 3.6 Flash; kiểm tra endpoint thành công.
2. Lượt ảnh dùng hết ngân sách 4.096 token trước khi tạo xong JSON. Đã tăng mức dự trữ mặc định lên 8.192 và nâng giới hạn đầu ra adapter lên 3.000 trong ngân sách còn lại. Câu 490 trả đúng với 3.935 token ở lượt thử sau.
3. Mô tả ảnh dài từng được trộn vào truy vấn Qdrant. Đã dùng từ khóa pháp lý từ bước vision để tìm kiếm, giữ mô tả ảnh cho phần trả lời.
4. Groq trả NoMatch ở câu 490 trong khi Gemini chọn đúng. Đã dùng Gemini cho lượt có ảnh, Groq cho câu hỏi chữ.
5. Prompt ban đầu không yêu cầu đầy đủ hai bước căn cứ GPLX. Đã thêm rule dẫn cả Điều 57 và Điều 59 khi câu hỏi đòi hỏi phân hạng xe và độ tuổi; câu 118 và 119 đã được thử lại và dẫn đủ cả hai điều.
6. Câu 493 cho thấy trích dẫn một điều luật không bảo đảm suy luận sa hình đúng. Đã thêm rule xét xe đã vào giao lộ và tránh tự động xếp xe ưu tiên đầu tiên. Chưa có bằng chứng live xác nhận bản sửa này vì Google trả 429.

## Giới hạn kết luận

Không thể buộc một model ảnh suy luận đúng mọi sa hình chỉ bằng prompt. Các ca 492–495 cần thử lại khi hạn mức Gemini phục hồi, và cần đánh giá với toàn bộ kho luật cùng luồng ứng dụng .NET/SQL thật. `Answered` có trích dẫn là bằng chứng về nguồn được chọn, chưa tự chứng minh rằng phép suy luận từ ảnh đến đáp án luôn đúng.
