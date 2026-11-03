# RAG local: bằng chứng chẩn đoán và khoảng trống bộ đánh giá — 03/11/2026

## Nguồn mẫu và giới hạn

Chỉ dùng nguyên tiêu đề Điều từ gói nguồn VBHN 55 Điều 56–89 đã đối chiếu, không soạn câu hỏi pháp lý mới. Script `scripts/check-local-legal-edition-4-citations.py` gửi chín tiêu đề qua Gateway/User/AI/Qdrant thật, lưu mọi lượt trong `artifacts/local-ai/heading-probe-56-89.json` (ignored). Kiểm `Answered`, có cite đúng Điều, ID chunk tồn tại trong SQL, SHA-256 đoạn, excerpt, URL nguồn và trạng thái Verified/Active. Đây là phép chẩn đoán retrieval/citation theo tiêu đề nguồn; **không phải** bộ câu hỏi đã duyệt hoặc đo đúng sai nội dung trả lời.

| Phạm vi nguồn | Điều thử | Cite đúng Điều và khớp SQL/URL, lượt đầu | Kết luận |
| --- | --- | --- | --- |
| GPLX, đào tạo, sát hạch | 56, 57, 64 | 3/3 | Cấu trúc trích dẫn đạt trong mẫu tiêu đề |
| Tuần tra, kiểm soát, điều khiển | 65, 79 | 2/2 | Cấu trúc trích dẫn đạt trong mẫu tiêu đề |
| Tai nạn, quản lý | 80, 87 | 2/2 | Cấu trúc trích dẫn đạt trong mẫu tiêu đề |
| Hiệu lực, chuyển tiếp | 88, 89 | 1/2 | Điều 88 lỗi API ở lượt đầu; thử lại riêng đạt 1/1, cite Điều 88 và 89. Giữ nguyên thất bại ban đầu trong báo cáo. |

Tổng lượt đầu: **8/9**. Retry riêng Điều 88: **1/1** (`artifacts/local-ai/heading-probe-88-retry.json`). Lượt retry không sửa kết quả lượt đầu. Sau edition 4, `scripts/check-local-rag-nomatch.py` chạy lại câu ngoài corpus đã có sẵn trong `scripts/check-local-ai.py` về mức phạt vượt đèn đỏ: `NoMatch`, 0 citation. Đây vẫn là phép thử kỹ thuật, chưa phải gold case đã duyệt.

Sau khi đồng bộ tiêu đề edition 4, hai lần thử riêng tiêu đề Điều 56 đều bị HTTP 503 từ chat vì Gemini generation trả HTTPError; SQL–Qdrant vẫn khớp 975/975. Lần thử sau được giữ ở `artifacts/local-ai/heading-probe-56-retry.json`, lần trước còn trong log inference. Không gộp các lần này vào 8/9 ban đầu hay coi là lỗi citation đã được giải quyết.

## Mẫu câu hỏi nguyên văn từ nguồn CSGT 2025

Sau phản hồi của người dùng, đã chọn **12 câu nguyên văn** từ gói 600 câu CSGT 2025 có PDF nguồn/hash, không yêu cầu người dùng cung cấp từng câu. Manifest `content-bank/legal/rag-eval-source-cases.json` ghi số câu, nguồn, ngày đánh giá và vị trí luật đối chiếu trong VBHN 55 edition 4. Chín câu có căn cứ gồm các nhóm khái niệm, người đi bộ, chuyển hướng, GPLX/tuổi, điểm GPLX và tai nạn. Ba câu 23, 25, 75 hỏi chế tài ngoài corpus hiện hành. Ánh xạ Điều/Khoản/Điểm là ứng viên do lần này đối chiếu với nguồn đã review, **chưa phải nhãn gold được người duyệt độc lập phê chuẩn**; bank 2025 cũng không tự chứng minh mọi đáp án còn hiệu lực năm 2026.

`scripts/evaluate-source-rag-cases.py` dùng nguyên câu hỏi và lựa chọn trong package, đo top‑5 Qdrant retrieval riêng với chat, kiểm ID/hash/excerpt/vị trí/URL của citation, và lưu tất cả lỗi vào `artifacts/local-ai/source-rag-evaluation-9-in-corpus.json` cùng `source-rag-evaluation-23-25-75.json` (ignored). Không trích lại đáp án của bank làm lời giải luật.

| Nhóm | Retrieval | Chat/citation | Giới hạn |
| --- | --- | --- | --- |
| 9 câu có căn cứ | Đủ mọi vị trí Điều/Khoản/Điểm kỳ vọng trong top‑5: **7/9**. Câu 119 thiếu Điều 57 khoản 1 điểm a; câu 194 thiếu Điều 80 khoản 1 điểm c. | **3 Answered** (câu 2, 118, 141), cả 3 cite đủ vị trí ứng viên và khớp ID/hash/excerpt/URL SQL; **6 lỗi HTTP 503** ở generation. | Chưa chấm đúng sai ngữ nghĩa câu trả lời; provider lỗi được giữ trong mẫu số. |
| 3 câu chế tài ngoài corpus | Cả 3 vẫn có **5 chunk luật** trong top‑5; retrieval chưa tự loại câu ngoài phạm vi. | Câu 75 `NoMatch`, 0 citation; câu 23 và 25 lỗi provider. | Chưa kết luận tỷ lệ abstention từ 1 ca thành công. |

Các số trên là **mẫu nhỏ từ nguồn có thật**, không phải ước lượng khả năng xử lý mọi câu hỏi của người dùng. Việc thiếu hai vị trí retrieval và lỗi provider là kết quả cần sửa/đo lại, không được thay bằng điểm số đẹp hơn.

## Bộ đánh giá cần hoàn thiện

Mẫu nguồn đã có câu nhiều điều/khoản và ngoài corpus, nhưng chưa có nhãn được duyệt độc lập cho **quy định cũ**, **quy định tương lai 2028/2029** và ngoại lệ chuyển tiếp. Vì vậy chưa thể tính độ đúng hiệu lực theo các nhóm đó, cũng chưa có precision/recall hay grounding ngữ nghĩa đủ tin cậy. Không chuyển tiêu đề chẩn đoán hoặc câu hỏi tự nghĩ thành gold set.

Mỗi gold case cần lưu nguyên văn câu hỏi được duyệt, nguồn và phiên bản, ngày áp dụng, các Điều/Khoản/Điểm kỳ vọng, URL kỳ vọng, quyết định `Answered`/`NoMatch`, cùng dấu vết người duyệt. Bộ chạy phải lưu cả response, chunks retrieval, citation và lỗi từng case để thất bại không biến mất khỏi mẫu số. NĐ 168/238 hiện vẫn inactive và không được dùng làm đáp án mức phạt hiện hành.

## Kiểm lại tối 03/11 sau khi khôi phục stack

Docker/SQL/Gateway/User/Content/AI/Qdrant được khởi động lại từ dữ liệu local hiện có. `scripts/check-legal-corpus-extension.py` đạt **975 SQL chunks = 975 Qdrant points**, toàn bộ payload khớp. Lần chạy đầu của `scripts/evaluate-source-rag-cases.py` cho 12 câu trả 6 `Answered`, 6 lỗi; đặc biệt câu chế tài 23 và 25 đã trả `Answered` dù chỉ cite VBHN 55. Đó là lỗi phạm vi căn cứ, không được tính là câu trả lời chế tài hợp lệ.

`TrafficRagGenerator` nay trả `NoMatch` sớm khi câu hiện tại hỏi xử phạt/mức phạt mà mọi chunk truy xuất chỉ thuộc VBHN 55. Không dùng lịch sử câu hỏi cũ để áp chính sách này; nếu về sau có văn bản chế tài đã xác thực trong retrieval, nhánh này không chặn generation. Script đánh giá cũng chuẩn hóa trường vị trí citation nullable để không lỗi khi sắp xếp. Kiểm lại riêng đúng ba câu nguồn 23, 25, 75: **3/3 `NoMatch`, 0 citation, 0 lỗi**. Unit AI **21/21 đạt**.

Chạy lại toàn bộ 12 câu sau sửa: **9/9 câu có căn cứ `Answered` với citation ID/hash/excerpt/URL khớp SQL; 3/3 câu chế tài `NoMatch`; 0 lỗi provider trong lượt này**. Trong chín câu có căn cứ, **7/9** lấy đủ mọi vị trí ứng viên trong top‑5 và cite đủ. Câu 119 còn thiếu Điều 57 khoản 1 điểm a (đứng thứ 33 trong truy xuất top‑50); câu 194 còn thiếu Điều 80 khoản 1 điểm c (đứng thứ 9). Cả hai vẫn trả `Answered` nhưng **chưa đạt tiêu chí đủ căn cứ nhiều ý**. Bằng chứng lượt mới ở `artifacts/local-ai/source-rag-evaluation.json` (ignored); không ghi đè các file/lượt thất bại trước đó. Chưa có đánh giá độc lập về đúng sai ngữ nghĩa hoặc gold set quy định cũ/tương lai. Một lượt hết lỗi provider không chứng minh provider ổn định lâu dài.

Lượt `scripts/check-local-ai.py` sau đó đạt các bước chat chữ, nối tiếp, `NoMatch` và `Blocked`, nhưng dừng tại ảnh câu 486: Gemini Vision trả **HTTP 429** và Gateway trả 503. Script có exit code 1; không ghi thành một lượt kiểm AI tổng thể thành công. Cần quota/provider khả dụng rồi chạy lại toàn bộ ca ảnh để nghiệm thu.

## Kiểm lại ca ảnh và chat đầy đủ

Đã cấu hình Gemini 2.5 Flash-Lite cho Vision và làm fallback generation khi Flash trả HTTP 429/500/503. Mô hình dự phòng vẫn phải trả JSON với ID của chunk đã truy hồi; không có lời giải dựng sẵn. Chỉ dẫn Vision trước đó luôn thêm ý “mức xử phạt”, làm câu ảnh về biển báo bị nhánh `NoMatch` chế tài chặn sai. Đã sửa để Vision tìm theo câu hỏi, còn điều kiện chế tài chỉ xét chính câu người dùng. Unit AI **22/22 đạt**.

Ảnh nguồn câu 486 cho thấy biển chỉ hướng làn và vạch mũi tên. Câu trắc nghiệm nguyên văn “xe nào chấp hành đúng” vẫn `NoMatch` khi chỉ đưa corpus luật vào RAG; không coi đó là lỗi cần ép câu trả lời. Kiểm chat ảnh dùng **chính ảnh nguồn**, hỏi quy tắc pháp lý về việc chấp hành biển báo/vạch kẻ đường. Lượt `scripts/check-local-ai.py --image-only` đạt `Answered` có citation Điều 10 khoản 1, đối chiếu ID/hash/excerpt/URL với SQL, lịch sử bền, quota và request lặp. Lượt chạy lại **toàn bộ** `scripts/check-local-ai.py` cũng đạt các ca chữ, nối tiếp, `NoMatch`, `Blocked` và ảnh; token quota trừ đúng một lần. Bằng chứng ở `artifacts/local-ai/live-check.json` (ignored). Các lỗi 429/503 trước đó vẫn là bằng chứng provider có thể gián đoạn.

## Thêm Groq generation với ba key local

Ngày 03/11, `.env` local có ba Groq key khác nhau; cả ba liệt kê được model từ API, key đầu tạo JSON thật. Launcher nay chọn `openai/gpt-oss-120b` cho Groq generation, luân phiên ba key và dùng Gemini khi Groq không tạo được kết quả hợp lệ. Các key không được ghi vào source/log. Thử model `qwen/qwen3.8-27b` trước đó cho JSON hợp lệ nhưng `NoMatch` ở ca ảnh dù retrieval có Điều 10; `gpt-oss-120b` trả `Answered` với citation Điều 10/13 cho cùng câu hỏi. Groq Vision thử riêng nhận diện sai một biển và đưa nghị định xử phạt cũ vào truy vấn, nên **không được bật** trong luồng demo; Vision và embedding vẫn là Gemini.

Lượt `scripts/check-local-ai.py` với Groq `gpt-oss-120b` **đạt toàn bộ**, log AI ghi ba generation thành công lần lượt ở key slot 1, 2, 3; không có Gemini generation trong lượt này. Lượt đánh giá lại 12 câu nguyên văn nguồn: **9/9 câu có căn cứ `Answered`, 3/3 chế tài `NoMatch`, 0 lỗi**, tất cả citation của ca `Answered` khớp ID/hash/excerpt/URL SQL. Truy xuất và citation nhiều ý vẫn chỉ **7/9** lấy đủ mọi vị trí ứng viên; câu 119/194 giữ giới hạn cũ. Kết quả Groq ở `artifacts/local-ai/source-rag-evaluation.json`; kết quả Gemini trước đó được giữ riêng trong `source-rag-evaluation-gemini-2026-11-03.json` (cả hai ignored). Đây là một lượt kiểm, không chứng minh Groq không bao giờ 429; quota Groq tính theo organization, không tự tăng khi nhiều key cùng tổ chức.
