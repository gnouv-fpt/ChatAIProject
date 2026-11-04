# Phúc — cập nhật code và kiểm tra trên máy nhận, 04/11/2026

Nhánh `PRN_Phúc_ASM` đã fast-forward tới `origin/PRN-dev` **027e4b7** trước khi làm tiếp. Nền mới đã tích hợp hai SQL contexts, bank 600 câu, profile B, 115 animation được duyệt, corpus và các module nhóm; báo cáo 28/10 không còn phản ánh phần đã được tích hợp.

## Phần tiếp tục trong lượt này

### P03/P06: import và preview đúng gói hiện hành

- Cả hai màn Admin đọc được bank JSON trần, `{bank, animations}` và gói đã duyệt `{bank, templates, evidence}`. Thiếu mảng `animations` được hiểu là mảng rỗng; không còn lỗi `.find` khi lưu gói 600 câu.
- Backend preflight đếm cả animation nằm trực tiếp trong câu hỏi: bank 600 hiện có **115 links**, không hiển thị sai là 0. Mapping cùng ID/URL chỉ đếm một lần; hai URL xung đột bị chặn.
- Ánh xạ được áp dụng ở `ContentBankImportService` phía server; import route không còn bỏ qua sidecar hoặc phụ thuộc client tự ghép dữ liệu. Trường `expectedManifestHash` tùy chọn ràng buộc đúng gói đã kiểm tra; client cũ chỉ gửi `{bank}` vẫn tương thích.
- Trước import/publish và khi preview lại, service kiểm URL theo allowlist hiện tại. Draft chứa host đã bị loại khỏi cấu hình không được publish. Không thêm trường vào serialized bank/profile, không đổi hash của các package hiện có.
- UI nói rõ bước nhập bank không tự nhập các đề mẫu trong gói. Không giả định nhiều API import/publish có transaction chung. Public questions DTO tiếp tục không chứa key/lời giải/animation URL.

### P05/bàn giao: bảo toàn chính xác bản đã duyệt khi clone

Các file text đã bị Git normalize về LF trong bản đóng gói trước. Hậu quả quan sát được trên clone này:

- SHA `scenes.json` khác `accepted-release.json`; Python từ chối dựng bank.
- Raw hash `bank.json` làm đổi ID bank 115 từ `aeabe38b-f3c7-5d52-82e6-0214b3b6d37c` thành ID khác.
- Các test giữ byte renderer thất bại; đối chiếu hosting thất bại dù nội dung sau chuẩn hóa xuống dòng giống nhau.

Đã phục hồi **chỉ LF/CRLF**, không đổi nội dung chuẩn hóa, actor/step/revision, nguồn ảnh hoặc đáp án. Hai JSON nguồn đối chiếu bằng hash duyệt/ID bank đã lưu; các renderer khóa được đối chiếu lock; các file phát hành đối chiếu byte với HTTPS hiện có. `.gitattributes` đặt `-text` cho content-animations để giữ đúng byte trên mọi nền tảng.

- SHA scenes sau phục hồi: `60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9`.
- Identity bank 115 giữ đúng `aeabe38b-f3c7-5d52-82e6-0214b3b6d37c`.
- Git archive từ commit **acca03b** giữ đúng SHA, identity và cả 115 revision. Không cập nhật manifest để hợp thức hóa hash sai.
- Test review lịch sử dùng feedback/baseline đã nằm trong Git; không còn đòi các file `output/` chỉ có trên máy tác giả. Các lần người dùng duyệt lại được tôn trọng; không áp trạng thái khóa cũ lên cảnh đã được yêu cầu sửa sau đó.

Diff asset khá lớn theo dòng do phục hồi byte; `git diff --ignore-space-at-eol` của chính thay đổi asset này rỗng. Không chạy authoring/sinh scene/model, không redeploy, không đổi dữ liệu bank đã xuất bản hoặc snapshot lịch sử. Hosting sẵn có: [115 animation HTTPS](https://content-animations.vercel.app/learn.html).

## Bằng chứng đã chạy trong lượt này

| Kiểm tra | Kết quả |
| --- | --- |
| `dotnet build ChatAIWeb.slnx` | Qua, 0 warning/error. |
| Content tests, đặt `PHUC_TEST_SQL` tới server local | **72 pass, 0 skip**. Test mới tạo database `PhucContentTests_<GUID>`, apply migrations Content có sẵn, import/publish bank HTTPS 600 câu, giữ 115 URL, replay không tạo trùng, xuất bản template và kiểm public DTO; database test được xóa sau khi qua. Không chạm database người dùng. |
| BusinessLogic tests | **23 pass, 0 skip**. |
| Node animation và content-import tests | **55 pass, 0 skip**, gồm geometry/historical approval/source bytes và đọc đúng hai gói 600 câu đang có. |
| Python `test*bank*.py` / `test_prepare_animation_links.py` | **10 + 6 pass**. |
| Frontend TypeScript/Vite build | Qua. |
| Models UserDbContext/ContentDbContext | Không pending model changes; không tạo migration mới. |
| HTTP public hosting | **735 file / 95.870.429 byte** khớp SHA local, gồm 115 learner pages. Không dùng đăng nhập/bypass và không phát hành deployment mới. |
| Dựng nguồn bank từ PDF SHA ghim | `prepare-question-bank-600.ps1` qua: 600 câu, 6 đề luyện tập, 115 animation cũ, không có warning. HTTPS verifier và profile B verifier đều qua; package/IDs/hash đang có được giữ nguyên. |

`PHUC_TEST_SQL` chỉ nhận connection **không có Database/Initial Catalog**, ví dụ `Server=localhost;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False`. Không đặt biến này tới DB đang dùng. Test áp dụng migrations đã có để kiểm isolated schema; không sinh/sửa migrations.

Bằng chứng local: `artifacts/phuc-2026-11-04/{newline-recovery,hosting-check}.json` và `approved-source-archive.zip` (Git ignored, không chứa credentials).

## Trạng thái task hiện tại để báo leader

| ID | Trạng thái có bằng chứng | Phần cần kiểm tiếp |
| --- | --- | --- |
| P01 | Parser/evidence và luồng import corpus đã có trong nền. | Crawler HTTP TVPL từng trả 403; không tuyên bố đã crawl tự động thành công. Luồng review/capture có kiểm nguồn là phương án riêng đã ghi ở báo cáo corpus. |
| P02 | SQL Content, chunks và workflow verify/index/deactivate đã được tích hợp. | Tái kiểm SQL–Qdrant/expiry/recovery trên stack máy nhận; không dùng kết quả mock để gọi AI thật đã chạy. |
| P03 | Import/publish SQL được kiểm với gói 600 câu thật trong DB test riêng; đã sửa envelope/mapping/hash review. | Chạy cùng UI/Gateway trên môi trường demo của máy nhận và giữ nguyên các bank/lịch sử có sẵn. |
| P04 | Questions/templates/service-only pool đã có trong nền; test SQL kiểm published template và public DTO không lộ đáp án. | Kiểm lại custom exam/review xuyên Gateway–Redis–User SQL sau khi runtime sẵn sàng. |
| P05 | 115 trang HTTPS đã có; toàn bộ 735 file kiểm khớp, đúng bản duyệt. Không còn chờ deploy fixture. | Không thay/sinh lại cảnh đã duyệt. Profile/hạng mới ngoài demo cần yêu cầu và review riêng. |
| P06 | UI thư viện/admin đã ghép; hai màn import đã sửa để dùng gói hiện hành; cron handler có trong nền. | Browser/Worker/cron end-to-end trên stack máy nhận và dựng lại demo từ máy sạch. |

**Không còn vướng “chưa có bank/chưa có schema P0”.** Việc còn lại tập trung ở 4 nhóm kiểm/chốt: crawler/nguồn HTTP; AI/Qdrant + expiry/recovery; UI/Gateway + custom exam/review; dựng và kiểm Worker/Docker trên máy nhận. Đây không phải khẳng định có thêm 4 module chưa code.

Docker engine trên máy hiện không truy cập được (`dockerDesktopLinuxEngine` chưa có pipe); chưa chạy lại bộ full-stack Redis/Kafka/Worker hoặc gọi AI provider trong lượt này. Các launcher demo còn dùng instance `.\MSSQLSERVER_VUON`; cần owner host cấu hình phù hợp máy nhận trước khi chạy. Đã kiểm SQL Content độc lập trên instance `localhost` đang chạy. Không sửa schema/entities/repo contracts, shared host/router, không reset containers/volumes hoặc tự chuyển database đang dùng.
