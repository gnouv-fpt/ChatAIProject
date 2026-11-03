# Mức sẵn sàng bàn giao tính năng và dữ liệu — 03/11/2026

Phạm vi người dùng chốt là **demo C2 hiện tại**: bank 600 câu và 115 mô phỏng, profile B hiện hành trong khoảng đã ghi, VBHN 55 Điều 1–89, chat chữ/ảnh, đề thi, Kafka/Worker và monitoring local. Đây là kiểm kê có bằng chứng, chưa phải xác nhận production. Trạng thái commit/push cần xem trực tiếp trong Git.

| Hạng mục | Bằng chứng hiện có | Điều kiện còn thiếu để gọi là bàn giao đủ |
| --- | --- | --- |
| User, Gateway, thi custom, Redis, Kafka/Worker | Build solution đạt; 154 bài .NET đạt (23 BusinessLogic, 66 Content, 64 ChatAIWeb, 1 integration). Kiểm tra live bank HTTPS qua Gateway: autosave 30 câu, nộp 29/30, review/history SQL bền, submit lặp giữ cùng attempt. | Chốt phạm vi demo/bàn giao ngoài máy và tái kiểm luồng sau khi đóng gói. |
| Bank câu hỏi và mô phỏng | Bank HTTPS 600 câu, 60 cờ điểm liệt theo gói nguồn, 319 ảnh và 115 animation links đã kiểm lại. Bank 115 và các bank cũ được bảo toàn. Profile B theo TT12 đến hết 28/02/2027 đã có. | Bảo toàn gói nguồn/asset khi đưa vào Git và thử dựng trên máy khác. Các profile hạng khác và quy tắc từ 01/03/2027 ở ngoài demo đã chốt. Không gọi bộ luyện tập là kỳ sát hạch chính thức. |
| Corpus quy tắc giao thông | VBHN 55/2026 Điều 1–89 active, edition 4, 975 SQL chunks và 975 Qdrant points khớp toàn bộ ID/hash/nội dung/vị trí/URL/trạng thái. | Kiểm hiệu lực theo từng quy định tương lai/chuyển tiếp; bộ câu hỏi gold được người duyệt độc lập xác nhận. |
| RAG trả lời | Với Groq `gpt-oss-120b` và ba key, lượt 12 câu nguồn: 9 `Answered`, 3 `NoMatch` chế tài, 0 lỗi; citation khớp SQL. `check-local-ai.py` chạy toàn bộ qua Gateway: chữ, nối tiếp, `NoMatch`, `Blocked`, ảnh thật đều đạt; ba lượt generation lần lượt dùng ba key. | Hai câu nhiều ý 119/194 chưa cite đủ vị trí ứng viên; chưa chấm ngữ nghĩa. Vision và embedding vẫn dùng Gemini, Groq cũng có thể trả 429 theo quota organization. Xem `LOCAL-RAG-EVALUATION-2026-11-03.md`. |
| Chế tài hiện hành | NĐ 168/2024 (55 điều) và NĐ 238/2026 (21 điều) đã đối chiếu nguồn; ledger 53 đơn vị sửa đổi/bãi bỏ đang inactive. | **Ngoài phạm vi demo C2 đã chốt**. Chat phải `NoMatch` khi chỉ có VBHN 55, không dùng bản 168 gốc hoặc ledger làm căn cứ hiện hành. |
| Observability | Sau khôi phục Docker, Grafana healthy, 6/6 Prometheus targets up, Gateway→User trace trong Tempo, 4 Loki streams cùng TraceId. Event nộp đề thật: lag 1 khi Worker dừng, về 0 sau restart; 1 xử lý duy nhất, 1 replay trùng bị bỏ qua, review SQL còn. | Retention hết hạn thật và backup/restore chưa nghiệm thu; alert firing/recovery đã thử ở lượt trước, chưa lặp lại trong lượt này. |

## Dữ liệu cần đóng gói

- `content-bank/` hiện **chưa được Git theo dõi**: gói 600 câu, profile B, review VBHN 55 và review NĐ 168/238. Sau khi đưa bốn capture công khai và PDF ký VBHN 55 vào gói, có 21 file, khoảng 7,3 MB. Giữ manifest nguồn/hash và trạng thái inactive của chế tài.
- `content-animations/` có 765 file, khoảng 102,5 MB local; gồm assets của 115 cảnh đã duyệt và ảnh bank. Không tái tạo hoặc sửa 115 cảnh để chuẩn bị Git.
- SQL/Qdrant/Redis/Kafka local giữ dữ liệu qua restart. Các `artifacts/` bị Git ignore, bao gồm runtime/secrets và bằng chứng máy đọc; Git source hiện **chưa tự chứa database backup**. Các launcher/importer nay nhận suffix database cô lập được tạo ở máy nhận, Qdrant collection theo suffix đó; đã kiểm trên stack hiện tại và chạy lại edition 4 idempotent. Quy trình dựng từ đầu trên máy khác vẫn chưa được chạy hết, nên chưa gọi là đã nghiệm thu tái lập.
- Working tree có hàng nghìn file untracked (đặc biệt `output/` và `tmp/`); phải chọn rõ source/asset/doc cần commit. Không dùng `git add .` để lấy cả kết quả thử nghiệm hoặc dữ liệu riêng tư.

## Kiểm tra trong lượt này

- `scripts/check-legal-corpus-extension.py`: version 4, 89 điều, 975/975 khớp.
- `scripts/prepare-question-bank-https.py --verify`: 600 câu, 319 assets, 115 links.
- `scripts/check-question-bank-600.py --https`: 600 câu từ SQL/Gateway, 60 cờ, 319 ảnh, 115 learner HTML, review/history/idempotent submit đạt.
- `scripts/test-c2-merged.ps1` trên database test mới: build 0 warning/error, 154/154 bài .NET đạt; database test được giữ lại để xem.
- `grpc_inference_service/test_unit.py`: 24/24; `npm --prefix web run build`: đạt.
- `scripts/evaluate-source-rag-cases.py`: 12 câu, 9 Answered/3 NoMatch/0 provider error ở lượt sau sửa; 7/9 câu có căn cứ lấy đủ mọi vị trí kỳ vọng top‑5.
- `scripts/check-official-b-and-bookmarks.py`: 27/30 đạt, 26/30 trượt, sai/bỏ trống câu điểm liệt trượt; bookmark song song và tách quyền user đạt.
- `scripts/check-local-ai.py`: lượt đầu lỗi tại ca ảnh do Gemini Vision HTTP 429. Sau khi cấu hình Vision Flash-Lite, generation fallback Flash-Lite và sửa truy vấn ảnh tự thêm ý xử phạt, lượt chạy lại **đạt toàn bộ** chữ/follow-up/NoMatch/Blocked/ảnh, citation ảnh đối chiếu SQL. Câu ảnh dùng ảnh nguồn 486 để hỏi quy tắc biển báo/vạch kẻ đường; câu trắc nghiệm “xe nào đúng” không được tính là câu trả lời RAG luật.
- `scripts/verify-monitoring.py --native`: lần đầu sau restart AI target còn `down` trước chu kỳ scrape; lần sau đạt Grafana, 6/6 targets, trace và Loki. `scripts/verify-local-monitoring-event.py`: event thật và duplicate replay đạt.
- Bốn gói VBHN 55 được dựng lại từ capture công khai trong `content-bank/legal/` và PDF ký có SHA-256 ghim: nội dung/manifest giữ nguyên. `scripts/extend-local-legal-corpus-56-89.py` chạy lại trên edition 4 trả cùng ID/hash/count và checker 975/975 đạt. Xem [runbook dựng demo](C2-DEMO-HANDOFF-2026-11-03.md).

Những kiểm tra này dùng dữ liệu và provider local thật tại thời điểm chạy; không chứng minh deploy/production hoặc mọi câu trả lời pháp lý đều đúng. Báo cáo được lập trước bước bàn giao Git; xem `git log` và remote ref để xác nhận commit/push sau đó.
