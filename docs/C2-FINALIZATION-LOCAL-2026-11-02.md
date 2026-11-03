# Profile hạng B, bookmark C2 và AI/RAG local — 02/11/2026

Đã triển khai và kiểm tra ba luồng trong stack local. Không commit, push, PR, merge hoặc deploy. Không tạo dịch vụ trả phí. Không sửa/tái tạo 115 cảnh đã duyệt. Hạng được cấu hình trong phiên này là **B**, theo bộ 600 câu đang có; không suy rộng sang hạng khác.

## Mở dùng

- Web: [http://127.0.0.1:18080/hoc](http://127.0.0.1:18080/hoc).
- Thi thử: chọn bank **Thi thử hạng B · 30 câu / 20 phút · quy tắc đến 28/02/2027**, rồi vào Luyện thi chọn đề **Thi thử B-01…B-06**. Bank luyện tập 80% trước đây vẫn giữ nguyên.
- Bookmark: nút **Đánh dấu câu hỏi / Đã đánh dấu** trong thư viện; xem/bỏ tại **Tiến độ học → bank tương ứng → Đã đánh dấu**.
- Chat: vào **Tư vấn pháp luật**. Ví dụ đã kiểm thật: hỏi về đèn đỏ, hỏi tiếp về đèn vàng nhấp nháy, hoặc đính kèm ảnh sa hình câu 486. Mở citation để xem đoạn nguồn và link TVPL.

## Profile thi thử theo quy tắc sát hạch hạng B

Nguồn đã mở và xem trực tiếp bản ký:

- [Thông tư 12/2025/TT-BCA](https://chinhphu.vn/?docid=213022&pageid=27160), [PDF Chính phủ](https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/3/15-bca.signed.pdf), **PDF trang 47–48, Phụ lục IV.A**: hạng B 30 câu, 20 phút, đạt tối thiểu 27; mỗi đề có một câu điểm liệt; sai câu này không đạt. Câu bỏ trống không được tính đúng; engine cũng không cho đạt khi bỏ trống câu điểm liệt.
- [Thông tư 108/2026/TT-BCA](https://chinhphu.vn/?docid=218725&pageid=27160), [PDF Chính phủ](https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/7/thong-tu-so-108.2026.tt-bca-ngay-29.6.2026-ban-day-du-v03.pdf), **PDF trang 36–37, Điều 41 khoản 6**: phần A Phụ lục IV của TT12 tiếp tục áp dụng đến hết 28/02/2027. Không lấy thông số của quy trình mới áp dụng từ 01/03/2027 để dùng trước thời điểm đó.
- Cấu trúc nội dung B và 60 số câu điểm liệt giữ nguyên theo CV2262/CSGT-P5 đã đối chiếu trong [báo cáo bank 600](LOCAL-QUESTION-BANK-600-2026-11-01.md).

| Thành phần | Giá trị |
| --- | --- |
| Bank thi thử mới / version | `cfa49411-a01c-50d6-88a2-7e25b1e888f7` / `1` |
| Hash Content API | `F5DC146565D8D2DB072F245E94278D36909FFAE668383802D7EEE7B18414C65B` |
| Profile ID | `gplx-B-tt12-2025-until-2027-02-28` |
| Policy | 30 câu, 1.200 giây, 27 câu đúng, `failOnCriticalWrong=true` |
| Mốc chặn tạo bài | Từ `2027-03-01T00:00:00+07:00`; backend yêu cầu đối chiếu quy định/ấn bản mới |
| Đề mẫu | `gplx-B-cfa49411-01` đến `-06`, version `1` |
| Catalog sau import | 4 bank, 1.915 hàng câu hỏi, 24 đề, 655 template items |

Đây là **thi thử theo thông số quy định**, không phải kỳ sát hạch tổ chức bởi cơ quan cấp GPLX. Sáu đề là các mẫu lựa chọn xác định, không phải bộ đề thi bí mật/chính thức. Không đổi bank luyện tập 80%, hash, IDs hoặc lịch sử cũ.

Gói mới nằm ở `content-bank/csgt-2025-B-current/package.json`. Namespace bank/câu/template mới gắn với nguồn, policy và hash hai PDF quy định. Không thêm field vào serialized `ExamProfile` cũ, vì cách đó sẽ làm đổi hash khi đọc lại các bank đã xuất bản. Metadata ngày/hạng/nguồn nằm trong evidence của edition; backend nhận diện policy đã đăng ký và kiểm cả thông số, cấu trúc, thời hạn. Tự chọn N/thời gian trên bank này bị từ chối; các bank luyện tập tiếp tục dùng tỷ lệ mục tiêu cũ.

## Bookmark C2

Người dùng đã cho phép trong chat: **“Cho phép sửa User schema và thêm migration local”** theo phương án đã nêu trước khi sửa schema.

- Migration tăng thêm: `DataAccess/Migrations/User/20261102035546_UserQuestionBookmarks.cs` và designer/snapshot tương ứng.
- User DB có bảng `QuestionBookmarks`: Id, UserId, QuestionId, CreatedAt UTC; unique (UserId, QuestionId), index (UserId, CreatedAt).
- Chỉ có FK UserId → Users. QuestionId là tham chiếu logic sang Content; không map navigation `Question` vào UserDbContext.
- Repository dùng đúng context của host; giữ constructor legacy cho các luồng/test cũ. Business service kiểm câu thuộc catalog đã xuất bản qua Content API trước khi thêm. List lọc các câu không còn hiển thị trước phân trang, giữ đúng total count.
- PUT/DELETE cùng câu idempotent cả khi có request đồng thời. Người khác không xem/xóa bookmark của chủ sở hữu.
- UI có trạng thái đang lưu, pressed/nhãn theo số câu, lỗi mất mạng và nút tải lại. Client nhận đúng HTTP 204 mà không cố parse body JSON rỗng.

Migration đã được apply explicit qua launcher vào **TrafficUser_WebLearning_57e824ae**, bảo toàn migration cũ. Content schema không thay đổi. Kiểm pending-model cho cả hai context đều không có thay đổi chưa được migration.

## AI/RAG thật và phạm vi corpus

Đã dùng **key Gemini hiện có** trong Presentation user-secrets, không ghi key vào command line, source hoặc runtime JSON. Groq hiện trả HTTP 403 trong kiểm tra models; launcher chọn Gemini rõ ràng, không thử Groq trước mỗi câu hỏi.

| Thành phần | Runtime local |
| --- | --- |
| Generation / vision | Gemini REST `gemini-2.5-flash` |
| Embedding | Gemini REST `gemini-embedding-001`, 768 chiều; task query/document riêng |
| gRPC | `127.0.0.1:15051`, chỉ bind loopback |
| Qdrant | Container local `prn-c2-localtest-qdrant-1`, `127.0.0.1:16333` |
| Collection riêng | `traffic_law_learning_57e824ae_gemini768_v1` |
| Qdrant client | `1.16.2`, constraint `>=1.15.0,<1.17.0` phù hợp server `1.15.5` hiện có |
| Content document | `047c3bb3-8f5e-401f-b151-029b60d62dab`, số `55/VBHN-VPQH`, version `1` |
| Corpus đã kích hoạt | **33 điều / 333 chunks**, Điều 1–33 của VBHN 55/2026 |

Nguồn corpus: [nội dung công khai TVPL của VBHN 55/2026](https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Van-ban-hop-nhat-55-VBHN-VPQH-2026-Luat-Trat-tu-an-toan-giao-thong-duong-bo-698683.aspx), đối chiếu với [bản hợp nhất trên Chính phủ](https://vanban.chinhphu.vn/?classid=0&docid=217295&pageid=27160) / [PDF](https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/3/55-vbhn-vpqh.pdf). Bản hợp nhất đã gồm sửa đổi Luật 118/2025 có hiệu lực từ 01/07/2026. Chỉ nhập phạm vi Điều 1–33 đã đối chiếu; không kích hoạt các quy định tương lai ở các điều ngoài phạm vi này.

**Phân biệt cách lấy nguồn:** crawler HTTP trên máy trả 403 từ TVPL, không được coi là crawl thành công. Nội dung công khai được đọc qua công cụ duyệt web, lưu bản thu nhận trong artifacts và so từng điều với PDF Chính phủ sau chuẩn hóa khoảng trắng. 32 điều khớp hoàn toàn; Điều 11 có một khác biệt dấu: PDF trang 11 in “người điểu khiển”, TVPL ghi “người điều khiển”. Đã xem trực tiếp vùng PDF, giữ wording TVPL và ghi chính xác khác biệt này vào manifest; không bỏ qua các khác biệt khác.

Gói review: `content-bank/legal/55-2026-articles-1-33.json`, hash PDF `9a20c8e616d444e3abe63c765a225d0797b7079c9a18e5fe7da0fc4f46847dac`. API admin mới cho phép import phạm vi từ source preview có hash, hoặc import bản thu nhận TVPL có hash + nguồn Chính phủ + ghi chú review. Cả hai nhập **Pending**, sau đó mới chạy verify-and-index. Import lại cùng gói giữ ID/chunks; nội dung/phạm vi khác bị conflict, không ghi đè văn bản đang dùng.

Các điểm đã sửa trong runtime:

- Thay Gemini model 1.5 cố định bằng REST model có cấu hình, dùng key trong header. Không cần SDK Google cũ để generation/vision.
- Embedding kiểm batch/order/dimension/vector; chia lô 32, tôn trọng retry của 429/503. Qdrant giữ từng lô đã ack và so payload/hash trước khi nhúng lại. Một lần index bị 429, lần tiếp theo hết deadline sau 224 chunks; chạy tiếp hoàn thành 333 mà không nhúng lại phần đã ack. SQL chỉ kích hoạt sau ack đủ.
- Retrieval theo câu hỏi/quan sát hiện tại; lịch sử vẫn vào prompt sinh câu trả lời, tránh lịch sử “đèn đỏ” lấn câu hỏi tiếp “đèn vàng”. Gemini trả schema có status và enum ID căn cứ đúng tập đã truy xuất. ID lạ/phản hồi thiếu căn cứ bị từ chối; không sinh câu trả lời bằng code local khi provider lỗi.
- Đoạn citation dùng substring thật, không nối `...` làm sai đối chiếu SQL. .NET kiểm ID/hash/nội dung/Điều/Khoản/Điểm/nguồn và trạng thái SQL trước khi lưu/trả kết quả.
- Gemini đếm context trước generation và giới hạn theo quota đã giữ. .NET chặn usage vượt reservation; không tự ước lượng usage không rõ. Vision usage tách theo thread để tránh lẫn giữa request đồng thời.
- Các văn bản gốc cũ đang bị sửa đổi từng phần (100/2019, 123/2021, 23/2008, 36/2024) không còn được registry cấp một trạng thái Verified chung cho toàn văn để đưa vào corpus mới.
- Chat UI giới hạn chiều cao tên citation dài; vẫn giữ title đầy đủ và link nguồn, không đổi snapshot đã lưu.

**Giới hạn nội dung:** corpus hiện là 33 điều quy tắc giao thông, chưa phải toàn bộ văn bản xử phạt hoặc mọi quy định giao thông hiện hành. Ca hỏi mức tiền phạt chính xác ngoài corpus đã trả `NoMatch`. Việc có citation đúng hash/SQL không phải thẩm định pháp lý mọi câu văn do mô hình sinh. Mở rộng corpus phải tiếp tục review nguồn/hiệu lực và nhập edition/phạm vi phù hợp; không bật toàn văn cũ để có câu trả lời bằng mọi giá.

## Kiểm tra đã thực hiện

- Build solution: qua, 0 warning/error. Bộ `test-c2-merged.ps1`: **148 .NET tests qua, 0 bỏ qua** (21 BusinessLogic + 63 Content + 63 ChatAIWeb + 1 C2 integration). Integration dùng SQL Server/Redis/Kafka thật trong DB fixture riêng.
- `pytest grpc_inference_service/test_unit.py -q`: **15 qua**; fixture/mock provider được phân biệt với kiểm thật bên dưới. Kiểm budget trước generation, grounding ID, exact excerpt, batching/recovery và wire contract.
- Python `unittest discover -s tests -p 'test*bank*.py'`: **10 qua**; thêm kiểm edition B không làm thay nguồn/policy luyện tập cũ.
- `npm --prefix web run build`: qua sau chỉnh UI cuối. EF pending-model User/Content: không có thay đổi chưa được migration.
- Gateway thật: **27/30 và đúng điểm liệt → đạt; 26/30 → trượt; 29/30 nhưng sai điểm liệt → trượt; 29/30 nhưng bỏ trống điểm liệt → trượt**. Active DTO không lộ key/lời giải, deadline đúng 20 phút; submit lại cùng attempt. Tự đổi N/thời gian bị 400. Đã sửa adapter để giữ 400/409 từ Content, không biến lỗi policy thành 500.
- Bookmark thật: PUT bốn request đồng thời tạo một hàng, DELETE đồng thời không lỗi; tài khoản khác không thấy/xóa được; câu không tồn tại trả 404. Restart host thật sau khi lưu, bookmark vẫn có trong SQL/API.
- AI thật qua Gateway → User → gRPC → Gemini generation/embedding/vision → Qdrant → kiểm Content SQL → lưu User SQL. Năm ca: chữ, follow-up đèn vàng nhấp nháy, NoMatch, Blocked, ảnh nguyên bản câu 486. Tất cả citation của Answered khớp SQL độc lập. Run đã kiểm tổng **10.077 token** được trừ đúng một lần; replay cùng request ID giữ message và không trừ lại. Đây là usage của run này, không phải mức cố định cho mỗi câu hỏi.
- Sau restart host: các message của run AI vẫn đọc lại được; bookmark vẫn tồn tại. Scroll toàn collection Qdrant: đủ **333 ID khác nhau**, từng payload/hash/nội dung/Điều/Khoản/Điểm/URL/flags khớp 333 SQL chunks đang Verified/Active.
- Browser thật: thư viện thêm/bỏ bookmark, offline lỗi rồi online retry, Progress tab/count/empty state, lưu lại từ thư viện. Thi thử B-01 → autosave → rời/resume không đổi deadline → nộp → review 1/30 → 9 link HTTPS/21 trạng thái chưa có mô phỏng → mở thật q486. Chat hiển thị Answered và mở citation Điều 11/link TVPL. Đã xem ảnh desktop/mobile 390 px, không tràn ngang trong các lượt kiểm. Network error ở lượt offline là chủ đích; không ghi nhận JavaScript page error trong hai script bookmark/exam.

Các lượt lỗi không tính là qua: kiểm schema ban đầu còn kỳ vọng 4 bảng User/1 migration, đã cập nhật thành đúng 5 bảng/2 migrations và thêm assert FK/unique; script API đầu chạm rate limit Gateway, sau đó tuân thủ Retry-After; adapter ban đầu trả 500 cho policy 400, đã sửa; một follow-up provider trả ID căn cứ không được retrieve và bị chặn, sau đó sửa retrieval/schema và kiểm lại trọn run thật. Script browser chat đầu chờ link đang đóng trong details nên timeout; mở citation và kiểm riêng kết quả đang hiển thị, không giả lập response.

## Bảo toàn và trạng thái Git/runtime

- Trước/sau: giữ nguyên hash từng hàng **1.315 câu, 6 categories, 18 templates, 475 template items và 11 ExamAttempts** có trước phiên này.
- Ba bank và 18 đề cũ giữ nguyên summary/hash/nội dung qua API. **765 file bảo vệ** không đổi: 763 file animation ngoài `.vercel` và hai file gói 600 local gốc. SHA scenes giữ nguyên `60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9`.
- Bank thi thử/import corpus chạy lại không tạo trùng. Baseline và bằng chứng ở `artifacts/c2-finalization/state-check.json`, `official-bookmarks-check.json`; AI ở `artifacts/local-ai/{source-comparison,import-result,live-check}.json`. Browser logs ở hai thư mục artifacts tương ứng; ảnh/scripts ở `output/playwright/`.
- Giữ **web/Gateway/User/Content/Worker/SQL/Redis/Kafka/Qdrant/gRPC** chạy local. Health HTTP cuối đều 200. SQL/Redis/Kafka giữ các dữ liệu có trước; không reset volume hoặc sửa remote.
- Branch vẫn `codex/prn-c2-integration-local`, HEAD `dbdcb5f0c723757d39429a518e4d29f20a2adba4`. Nhiều thay đổi/untracked từ trước và phiên này còn local; không stage/commit/push/PR/deploy.

## Chạy lại

```powershell
# Chỉ khi các process chưa chạy; secrets giữ trong user-secrets hoặc env GEMINI_API_KEY.
pwsh -NoProfile -File scripts/start-c2-test-infrastructure.ps1 -Ai
pwsh -NoProfile -File scripts/start-local-ai.ps1
pwsh -NoProfile -File scripts/start-local-learning.ps1 -EnableAi

# Gói đã có: verify/prepare lại từ source cache có hash, không ghi đè edition khác.
python -X utf8 scripts/prepare-official-b-bank.py --verify
pwsh -NoProfile -File scripts/import-question-bank-600.ps1 -OfficialB
python -X utf8 scripts/import-local-legal-corpus.py
python -X utf8 scripts/check-c2-finalization-state.py

# Các kiểm tra tạo tài khoản/lượt thi/chat test mới, có gọi provider thật:
python -X utf8 scripts/check-official-b-and-bookmarks.py
python -X utf8 scripts/check-local-ai.py
```

Không chạy start lần nữa khi process đang chạy. Khi cần restart web/API dùng `start-local-learning.ps1 -Stop` rồi start `-EnableAi` (hoặc thêm `-SkipBuild` nếu source/binary phù hợp). AI có lệnh stop riêng `start-local-ai.ps1 -Stop`. Venv hiện có tại `artifacts/c2-python/.venv`; cài dependency từ `grpc_inference_service/requirements.txt` nếu dựng máy mới. Secrets/tài khoản test chỉ ở nơi Git-ignore; không copy artifacts vào source.

Các profile cho hạng khác, corpus xử phạt rộng hơn, rà soát pháp lý toàn bộ ngân hàng/đáp án theo luật mới, điện thoại thật và triển khai toàn hệ thống chưa được chứng minh bởi phiên này. Không thay những giới hạn đó bằng kết quả unit test hoặc bộ thi thử local.
