# Dựng lại demo C2 local từ source và gói dữ liệu

Phạm vi: 600 câu CSGT 2025, 115 animation đã duyệt, profile thi thử B đến hết 28/02/2027, VBHN 55 Điều 1–89 và các host C2 local. Bank/đề là dữ liệu luyện tập và thi thử; không phải kỳ sát hạch chính thức. NĐ 168/238 vẫn inactive. Các lệnh chỉ dành cho database cô lập của launcher, không nhắm database có sẵn của người dùng.

## Trước khi chạy

### Chạy nhanh trên máy Windows với SQL Server trong Docker

Từ thư mục gốc, chạy `CHAY-LOCAL.bat` hoặc `pwsh -NoProfile -File scripts/run-local.ps1`.
Lần đầu script tạo hai database riêng trong container SQL Server, tải và kiểm SHA các PDF nguồn đã ghim, chạy migration có sẵn, rồi nạp 115 câu sa hình, bộ 600 câu ôn tập và bộ 600 câu thi thử B. Redis, Kafka và Qdrant cũng chạy trong Docker. Web mở tại `http://127.0.0.1:15173`; tài khoản demo local dùng chung là `admin@local-learning.test` / `LocalDemo@123456`. Thông tin này cũng được ghi trong `artifacts/local-learning/DANG-NHAP.txt` (Git ignore). Mật khẩu chỉ dành cho môi trường local, không dùng trên server. Nếu DB local đã có admin với mật khẩu cũ, chạy lại `CHAY-LOCAL.bat` sẽ cập nhật mã băm mật khẩu của đúng tài khoản admin đó; dữ liệu học và đề thi được giữ lại. Để dừng các tiến trình do script tạo, chạy `pwsh -NoProfile -File scripts/run-local.ps1 -Stop`. Không dùng `docker compose down -v`, vì lệnh đó xóa dữ liệu DB.

Máy mới chỉ cần cài Docker Desktop (đang chạy), .NET 8 SDK, Node.js/npm, Python có pip và PowerShell 7. Script tự cài `dotnet-ef`, `PyMuPDF 2.0` và thư viện web khi thiếu. Mỗi máy vẫn tạo DB, mật khẩu SQL và khóa JWT riêng; chỉ tài khoản demo local dùng chung. Không commit `artifacts/`, `.env` hoặc Docker volume. Nhớ commit cả `CHAY-LOCAL.bat`, `scripts/run-local.ps1`, các script sửa đổi, `content-bank/`, `content-animations/` và migration trước khi push.

Phần hỏi đáp AI và lập chỉ mục văn bản cần cấu hình Gemini key cùng môi trường Python AI theo các bước đầy đủ bên dưới. Khi chưa có khóa, câu hỏi và thi thử vẫn chạy, còn Văn bản và Chat chưa có dữ liệu pháp luật đã kích hoạt. Tất cả host ứng dụng và cổng Docker được mở trong máy local; không có bước deploy.

- Trình tự thủ công bên dưới dành cho stack cũ dùng SQL Server trên Windows: PowerShell 7, .NET 8 SDK + `dotnet-ef`, instance `.\MSSQLSERVER_VUON`, Docker Desktop, Python, Node/npm và `sqlcmd`. Đường chạy nhanh Docker ở trên không cần SQL Server hoặc `sqlcmd` cài trên máy.
- Python cần `PyMuPDF` bản **2.0** để đối chiếu lại PDF pháp luật; các script cũng tìm package tại `%TEMP%/prn_pdf_tools`. Python AI dùng venv `artifacts/c2-python/.venv` cài từ `grpc_inference_service/requirements.txt`.
- Gemini key nằm trong Presentation user-secrets (`Llm:Gemini:ApiKey`) hoặc `GEMINI_API_KEY` của phiên shell. Groq generation đọc `GROQ_API_KEYS`/`GROQ_API_KEY` từ biến môi trường hoặc `.env` local (Git ignore); mặc định dùng `openai/gpt-oss-120b`. Không đưa key vào repo. Vision/embedding và import vẫn cần quota Gemini; 429 khi import sẽ giữ trạng thái staging để chạy lại, không coi là hoàn thành.
- Clone phải chứa cả `content-bank/`, `content-animations/`, `scripts/`, migrations và source app. `artifacts/` được Git ignore, chỉ giữ cache, bằng chứng và runtime/secrets local.

## Trình tự trên máy mới

```powershell
python -m pip install pymupdf==2.0
python -m venv artifacts/c2-python/.venv
& artifacts/c2-python/.venv/Scripts/python.exe -m pip install -r grpc_inference_service/requirements.txt
npm --prefix web ci

pwsh -NoProfile -File scripts/start-c2-test-infrastructure.ps1 -Ai
pwsh -NoProfile -File scripts/start-local-learning.ps1 -InitOnly
pwsh -NoProfile -File scripts/start-local-ai.ps1
pwsh -NoProfile -File scripts/start-local-learning.ps1 -EnableAi
pwsh -NoProfile -File scripts/import-local-learning.ps1

# Tải lại PDF nguồn đã ghim SHA, dựng bank 600 và hai edition B/HTTPS.
pwsh -NoProfile -File scripts/prepare-question-bank-600.ps1
pwsh -NoProfile -File scripts/import-question-bank-600.ps1
python -X utf8 scripts/prepare-question-bank-https.py --verify
pwsh -NoProfile -File scripts/import-question-bank-600.ps1 -Https
python -X utf8 scripts/prepare-official-b-bank.py --verify
pwsh -NoProfile -File scripts/import-question-bank-600.ps1 -OfficialB

# Các capture công khai và PDF ký VBHN 55 đã có trong content-bank/legal.
# Import tuần tự, chờ mỗi bước hoàn thành và kiểm kết quả trước bước sau.
python -X utf8 scripts/import-local-legal-corpus.py
python -X utf8 scripts/extend-local-legal-corpus.py
python -X utf8 scripts/extend-local-legal-corpus-50-55.py
python -X utf8 scripts/extend-local-legal-corpus-56-89.py
python -X utf8 scripts/check-legal-corpus-extension.py
```

`start-local-learning.ps1 -InitOnly` tạo suffix database cô lập và credential local trong `artifacts/local-learning/runtime.json`; AI dùng cùng suffix cho Qdrant collection. Không sao chép runtime JSON của máy khác. Bốn gói VBHN 55 được tạo/đối chiếu từ capture/PDF trước import; bản PDF ký trong repo có hash `9a20c8e616d444e3abe63c765a225d0797b7079c9a18e5fe7da0fc4f46847dac`. Các importer giữ ID/hash của mỗi lần retry cùng gói; không dùng `down -v` hoặc xóa SQL/Qdrant để xử lý lỗi giữa chừng.

## Cổng kiểm tra demo

```powershell
python -X utf8 scripts/check-question-bank-600.py --https
python -X utf8 scripts/check-official-b-and-bookmarks.py
python -X utf8 scripts/check-legal-corpus-extension.py
python -X utf8 scripts/check-local-ai.py
npm --prefix web run build
```

`check-local-ai.py` dùng Groq để sinh câu trả lời khi có key; key được luân phiên theo lượt và mỗi key được thử tối đa một lần khi gặp lỗi quota/kết nối, sau đó mới sang Gemini. Groq áp quota theo organization nên ba key cùng organization vẫn có thể cùng trả 429 ([Groq rate limits](https://console.groq.com/docs/rate-limits)). Vision Flash-Lite và embedding Gemini vẫn cần quota. Ca ảnh dùng ảnh nguồn câu 486 để hỏi quy tắc biển báo/vạch kẻ đường trong corpus, không dùng RAG luật để chấm đáp án trắc nghiệm xe nào đúng. Nếu provider vẫn lỗi, giữ nguyên thất bại và chạy lại khi quota khả dụng; không thay bằng câu trả lời giả. Kiểm monitoring/Worker và số liệu Kafka theo [báo cáo observability](LOCAL-EDITION4-SANCTIONS-MONITORING-2026-11-03.md). Bài `check-legal-corpus-extension.py` phải đạt edition 4, 89 điều và 975/975 SQL–Qdrant.

Runbook mới chỉ được thử idempotent trên stack hiện tại; **chưa có lượt dựng từ đầu ở một máy thứ hai**. Đây là bước nghiệm thu cuối cho khả năng bàn giao dữ liệu tái lập.
