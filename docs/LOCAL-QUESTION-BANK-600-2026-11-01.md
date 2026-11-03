# Ngân hàng nguồn 600 câu — bàn giao local 01/11/2026

**Cập nhật 02/11:** đã thêm [bank dùng tài nguyên HTTPS](LOCAL-BANK-HTTPS-2026-11-02.md) độc lập, bảo toàn gói local/hash/lịch sử trong báo cáo này. Catalog hiện có 3 bank / 18 đề; chọn bank có hậu tố **ảnh/mô phỏng HTTPS** để dùng hosting đã phát hành.

Đã nhập đủ **câu 1–600** vào gói luyện tập mới trong Content SQL local, bổ sung phần nguồn **1–485** còn thiếu. Bộ 115 câu cũ và sáu đề cũ vẫn tồn tại độc lập, giữ nguyên hash/nội dung. Không sửa hoặc tái tạo cảnh 3D đã duyệt; không commit, push, PR hoặc deploy.

Mở [web local](http://127.0.0.1:18080/hoc), đăng nhập và chọn **600 câu CSGT 2025 · luyện tập local**. Trong Luyện thi có thêm sáu đề **Luyện tập 01–06 · cấu trúc B CV2262/2025 · mục tiêu 80%**. Nguồn là ấn bản 2025 được ghi rõ; không khẳng định mọi quy định vẫn còn hiệu lực vào năm 2026.

## Nguồn và phạm vi đối chiếu

- [PDF 600 câu trên kho dữ liệu chính quyền Tuyên Quang](https://khodulieu.sohoa.tuyenquang.gov.vn/congthongtin/media/edb12a6ad8ecfde537ec02cbb7e2a1b1.pdf): tải lại thành công, **186 trang**, SHA-256 `d473be679b53458a33acc52057f3a4fe532ea489e91d88fb86789073cd98a9c5`. Đây chính là nguồn của bộ 115 câu đã được dùng trước đó.
- [Thông tin công bố của Công an Tuyên Quang](https://congan.tuyenquang.gov.vn/vi/tin-bai/bo-600-cau-hoi-dung-cho-sat-hach-lai-xe-co-gioi-duong-bo?id=157456&type=EXECUTIVE_DIRECTION) xác định số 2262/CSGT-P5, ngày 07/05/2025, cơ quan ban hành Bộ Công an.
- [Bộ 600 câu trên website Cục CSGT](https://www.csgt.vn/upload/services/273963059_B%E1%BB%99%20600%20c%C3%A2u%20h%E1%BB%8Fi%20d%C3%B9ng%20cho%20s%C3%A1t%20h%E1%BA%A1ch%20l%C3%A1i%20xe%20c%C6%A1%20gi%E1%BB%9Bi%20%C4%91%C6%B0%E1%BB%9Dng%20b%E1%BB%99.pdf): nội dung được công cụ duyệt web đọc là ấn bản Cục CSGT, Hà Nội 2025, cùng bố cục và câu hỏi. Tải raw bằng PowerShell hiện trả một PDF trang chủ 17 trang, nên **không dùng file trả về đó làm dữ liệu** và không khẳng định byte hash trùng bản Tuyên Quang.
- [CV2262 trên Cục CSGT](https://www.csgt.vn/upload/services/2071319603_H%C6%B0%E1%BB%9Bng%20d%E1%BA%ABn%20s%E1%BB%AD%20d%E1%BB%A5ng%20b%E1%BB%99%20c%C3%A2u%20h%E1%BB%8Fi%20s%C3%A1t%20h%E1%BA%A1ch%20GPLX%20%28CV%202262.07.5.2025%29.pdf) xác nhận phạm vi sáu chương, đáp án gạch chân, cấu trúc hạng B và danh sách câu điểm liệt ở Phụ lục 3. Bản PDF sáu trang đọc bằng Python được tải từ [bản lưu Thư Viện Pháp Luật](https://cdn.thuvienphapluat.vn/uploads/DanLuat-BanAn/2025/5/huong-dan-so-2262-csgt-p5.pdf), SHA-256 `dcb0b42473a23af3b006ed07cfd3a728254eb3d5263f6a26d0536c576d69e634`. Danh sách 60 số câu khớp nội dung Phụ lục 3 đọc trên Cục CSGT.

| Phạm vi theo CV2262 | Số câu | Loại nội bộ |
| --- | ---: | --- |
| 1–180: quy định chung, quy tắc giao thông | 180 | RULES |
| 181–205: văn hóa, đạo đức, phòng cháy, cứu nạn | 25 | CULTURE |
| 206–263: kỹ thuật lái xe | 58 | DRIVING |
| 264–300: cấu tạo, sửa chữa | 37 | MECHANICS |
| 301–485: báo hiệu đường bộ | 185 | SIGN |
| 486–600: sa hình, xử lý tình huống | 115 | SCENARIO |

Đối chiếu tự động từng câu với PDF gốc: số thứ tự, nội dung, lựa chọn theo đúng nhãn, nét gạch chân theo tọa độ/baseline và byte ảnh gốc. Không OCR/LLM suy luận đáp án. Có đủ 600 số câu liên tục, 600 ID riêng, mỗi câu đúng một key trong 2–4 lựa chọn, không có bản trùng hoàn toàn nội dung/lựa chọn/ảnh. Câu giống prompt nhưng ảnh khác không bị coi là trùng. Cả 115 câu cuối khớp hoàn toàn prompt/options/key/trang nguồn/hash ảnh của manifest đã có.

Đã xử lý lựa chọn nhiều cột ở câu 301/302 và ba lựa chọn trên cùng dòng ở 352 bằng bbox từng đoạn chữ, tránh ghép lựa chọn hoặc nhận nhầm nét gạch chân. Đã nhìn trực tiếp vùng PDF các câu 1, 19, 206, 264, 301, 302, 352, 485 và trang gồm 337–339. Đây là kiểm tra bằng hình ảnh có chọn mẫu, **không phải người dùng đã duyệt thủ công 485 câu mới**. Whitespace được chuẩn hóa, không biên tập lại nội dung nguồn; ví dụ chỗ ngắt dòng giữa “b” và “ộ” ở phương án 2 câu 3 vẫn được giữ dưới dạng “b ộ”.

Phần 1–485 có **204 ảnh ở 203 câu**, 282 câu không có ảnh trong PDF. Toàn bộ 600 câu có **319 ảnh ở 318 câu**. Không thêm ảnh cho câu chỉ có chữ. Ảnh là byte JPEG/PNG trích từ PDF, giữ cả nhãn biển nằm trong ảnh.

## Phiên bản, DB và bảo toàn

| Thành phần | Giá trị thực tế |
| --- | --- |
| Content DB riêng đang dùng | `TrafficContent_WebLearning_57e824ae` |
| User DB riêng giữ nguyên | `TrafficUser_WebLearning_57e824ae` |
| Mã ấn bản nguồn | `CSGT-600-2025-CV2262` |
| Bank mới / version nội bộ | `a2fdea91-efe0-592e-9e2a-6b8a4a0fa069` / `1` |
| Hash package do API trả | `C54645FD5DD27EE4846A0BC7A01D6C6892F6DAA85B38C79CAA65713A9AB7E590` |
| Bank cũ | `aeabe38b-f3c7-5d52-82e6-0214b3b6d37c` / `1`, 115 câu |
| Hash bank cũ giữ nguyên | `1CA6EAF8B7D0363F6610AEB87A289BD77D1B9E280F3902E15E9A01CB0787DF8F` |
| Cảnh đã duyệt | 115 liên kết, đúng `q486.html`–`q600.html` |
| SHA scenes giữ nguyên | `60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9` |
| Tổng DB sau import | 2 bank, **715 hàng câu hỏi**, 12 đề mẫu |

715 hàng gồm gói 600 và snapshot 115 cũ; **không phải 715 câu nguồn khác nhau**. Phần 486–600 có mặt trong hai gói với GUID khác nhau để bảo toàn lượt làm bài cũ. Không sửa ID hoặc nội dung bank cũ để ghép thêm câu. Gói mới dùng lại URL ảnh và mô phỏng cũ cho đúng 115 câu cuối; 1–485 có `ExplanationAnimationUrl = null`.

GUID gói mới gắn với manifest nguồn, gói 115 đã duyệt và policy luyện tập; ID câu gắn với gói và nội dung câu. Chạy lại cùng nguồn/policy giữ ID/hash; thay nội dung cần gói có identity khác, không ghi đè version đã nhập. Importer phát hiện conflict ở bank/template trước khi thay đổi dữ liệu cũ, kiểm hash sau import, và có thể chạy tiếp sau gián đoạn. Import bank và các template qua nhiều API là các bước riêng, không hứa transaction chung cho toàn bộ quy trình.

Chỉ mở rộng whitelist validation nghiệp vụ thành sáu loại nội dung bên trên. Cột `TrafficQuestionCategories.Type` hiện là string tối đa 30 ký tự, không có SQL constraint giới hạn SIGN/SCENARIO. **Không sửa shared entity, DbContext, repository contract, migration hoặc snapshot EF.** Đây là bổ sung phân loại cho importer local, cần đồng bộ contract P0 khi tích hợp chính thức. Các migration sẵn có được launcher kiểm tra explicit trên DB riêng; lượt restart cuối báo không có migration nào cần áp dụng.

## Đề mẫu và chính sách luyện tập

Sáu đề mới, mỗi đề 30 câu, chọn xác định để chạy lại ổn định. Cấu trúc theo mục II.1 CV2262 cho hạng B: **8 quy tắc + 1 câu điểm liệt + 1 văn hóa + 1 kỹ thuật + 1 cấu tạo + 9 biển báo + 9 sa hình**. Pool các nhóm thường loại câu điểm liệt ra trước khi chọn để mỗi đề có đúng một câu đó. Không tự áp cấu trúc này cho hạng A/A1/B1.

60 cờ `isCritical` lấy nguyên danh sách Phụ lục 3, không suy ra từ số thứ tự, ảnh hoặc nội dung. Profile vẫn là **luyện tập**, 30 phút, mục tiêu 24/30 (80%), `failOnCriticalWrong=false`. Thời gian và mục tiêu này là chính sách tự luyện local, **không phải ngưỡng/thời lượng thi GPLX chính thức**. CV2262 đủ căn cứ về danh sách/cấu trúc nhưng phiên này chưa xác minh bộ văn bản hiện hành về ngưỡng đạt/thời lượng đúng hạng/ấn bản để bật profile sát hạch chính thức.

Lời giải 1–485 chỉ dẫn đáp án gạch chân và trang PDF; không sáng tác giải thích luật hoặc số Điều/Khoản. Phần 486–600 dùng lại diễn giải từ mô phỏng đã duyệt. Thư viện hiển thị lựa chọn, không key/lời giải; key chỉ xuất hiện sau nộp trong review.

## Quy trình chạy lại

PowerShell 7, Python và PyMuPDF; phiên này dùng PyMuPDF **2.0** từ thư mục công cụ PDF đã có. Builder hỗ trợ cả package cài trong Python lẫn `%TEMP%/prn_pdf_tools`. Không cài thêm dependency trong phiên này. Bộ trích xuất giữ tọa độ, nên cần kiểm lại manifest nếu thay phiên bản PyMuPDF.

```powershell
# Repo này; Docker Desktop và SQL .\MSSQLSERVER_VUON sẵn sàng.
pwsh -File scripts/prepare-question-bank-600.ps1
# Nếu stack chưa chạy:
pwsh -File scripts/start-c2-test-infrastructure.ps1
pwsh -File scripts/start-local-learning.ps1
# Nếu stack đang chạy thì không chạy start lần nữa.
pwsh -File scripts/import-question-bank-600.ps1
python -X utf8 scripts/verify-question-bank-600.py
python -X utf8 scripts/check-question-bank-600.py
```

`prepare` chỉ nhận PDF đúng SHA đã ghim, không nhận trang chủ/redirect hay bộ 2020 thay cho 2025. File có nội dung khác bị từ chối, không tự ghi đè. `verify` trích xuất lại toàn bộ câu/key/ảnh từ PDF và so manifest/package, kiểm hash ảnh, bản duyệt/revision/scenes và HTML learner đúng số câu. `import` chỉ nhận các host local-learning được ghi nhận, kiểm PID/cổng Content và DB riêng có bank 115 trước khi ghi. Dùng API admin hiện có và publish **trong DB local**. Không gửi dữ liệu hoặc deploy ra hosting.

Sau khi đổi backend cần dừng các process của launcher bằng `start-local-learning.ps1 -Stop`, rồi start lại. Đã sửa lỗi ghép bốn URL health thành một chuỗi trong vòng readiness của launcher; restart thật với `-SkipBuild` đã báo ready. Script kiểm tra bank 115 cũ cũng đã được điều chỉnh để chọn đúng bank/sáu đề của nó khi catalog có thêm bank.

Source cache và tài khoản test ở `artifacts/question-bank-600/`, thuộc Git ignore. Không copy runtime/account vào source. Manifest/package review được ở `content-bank/csgt-2025/`; 204 ảnh mới ở `content-animations/question-bank-600/`. Builder không ghi file nào trong vùng 115 cảnh cũ.

## Bằng chứng kiểm tra

- `dotnet test tests/Content.Tests/Content.Tests.csproj`: **59 qua, 0 bỏ qua**. Có kiểm thử cho bốn loại lý thuyết giữ đúng phân loại và loại không hỗ trợ bị chặn.
- Python `unittest discover -s tests -p 'test*bank*.py'`: **8 qua**, gồm 4 kiểm tra cũ và 4 mới; kiểm thiếu key/ảnh, trùng số/nội dung, liên kết mô phỏng sai, lựa chọn nhiều cột, identity và policy.
- Build Presentation, ApiGateway, WorkerService: qua, 0 warning/error. `npm run build` cuối sau sửa CSS: qua.
- `prepare` chạy lại giữ cùng ID/package. Importer chạy lại thành công, vẫn **2 bank / 12 đề**, không thêm hàng trùng; hash bank 115 giữ nguyên.
- `check-question-bank-600.py`: Gateway trả đủ 600 câu giống nội dung/options/ảnh của package; SQL thật có 600 hàng/60 cờ/115 URL; tải **319 ảnh** đối chiếu hash và **115 learner HTML** đúng số câu; đối chiếu cả sáu đề mới và baseline sáu đề cũ.
- Bài API thật lưu 30 câu trả lời, cố ý sai đúng một câu nguồn điểm liệt, được **29/30, isPassed=true** vì đây là luyện tập; review/history SQL đúng bank/version/key/URL, submit lại cùng attempt. Không dùng business API giả lập.
- Browser thật: đề mẫu B-01 có 30 câu, key/lời giải ẩn khi làm; lưu một đáp án, rời trang, resume giữ answers/deadline; nộp **1/30**, review 29 chưa trả lời, **9** link sa hình và **21** trạng thái chưa có mô phỏng; mở popup thật `q486.html`; lịch sử có đúng attempt `cf2d7acd-978d-4731-8db3-09fba42785c6`. Lượt kiểm tra này không ghi nhận JavaScript error.
- Ảnh desktop 1440 và mobile viewport 390 đã xem trực tiếp. Câu 301 có đủ 4 lựa chọn, câu 352 đủ 3; ảnh nguồn tải được. CSS chỉ thêm wrap nguồn dài và giới hạn select, giữ visual language. Kiểm tăng font gốc 14 → 28 px cho thư viện không vượt viewport; không thay cho kiểm trên thiết bị thật.
- So SHA trước/sau: **561 file animation có trước không đổi**, gồm scenes, renderer, models, review JSON, ảnh và learner pages. Không chạy authoring lại.

Bằng chứng máy đọc: `artifacts/question-bank-600/import-result.json`, `before-import.json`, `live-check.json`, `browser-check.json`, `browser-history-mobile.log`, `protected-before.json`. Ảnh ở `output/playwright/bank600-*.png`; script browser ở cùng thư mục.

Trong quá trình chạy đã sửa lỗi mảng lồng trong bản đầu importer PowerShell; bản kiểm tra ban đầu báo nhầm “existing bank changed”, trong khi đối chiếu SQL/API cho thấy hash bank cũ không đổi. Một lượt importer bị ngắt kết nối khi restart stack; chạy lại sau ready thành công, không đổi ID/hash/count. Hai lỗi locator/đăng nhập do reload trong script browser đã được sửa và xác minh bằng lượt sau; không coi các lượt lỗi đó là bằng chứng qua. Không sửa dữ liệu để làm kiểm tra đạt.

## Phần còn lại

Ngân hàng local đã đủ 600 câu của ấn bản nguồn nói trên. Chưa có profile thi GPLX chính thức theo quy định hiện hành; chưa có người dùng duyệt thủ công riêng từng câu 1–485; chưa kiểm thiết bị di động thật hoặc cập nhật điều luật độc lập cho mỗi câu. Bộ sáu đề mẫu chỉ là các ví dụ luyện tập theo cấu trúc đã xác minh, không phải bộ đề thi chính thức.

Hosting HTTPS, triển khai ngoài máy, AI/RAG và các giới hạn C2 khác vẫn ngoài phiên này. Toàn bộ thay đổi còn local trên `codex/prn-c2-integration-local`, HEAD `dbdcb5f0c723757d39429a518e4d29f20a2adba4`. Working tree vốn đã có nhiều sửa đổi/untracked; không stage, commit, push, PR, merge hoặc deploy.
