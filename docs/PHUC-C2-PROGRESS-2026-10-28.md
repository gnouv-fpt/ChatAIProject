# Phúc — tiếp tục theo C2 bản 27/10 (28/10/2026)

Nhánh bàn giao: `PRN_Phúc_ASM`. Đã merge `origin/PRN-dev` tại `e0d53bb`, giữ hai commit Phúc cũ. Bản này thay trạng thái triển khai trong PHUC-CONTENT-HANDOFF.md ngày 26/10; task IDs theo plan 27/10.

## Code tiếp được khi chờ P0

| Task | Kết quả trong lượt này | Chưa nghiệm thu |
| --- | --- | --- |
| P01 | Admin preview nguồn thật qua typed HTTP client không redirect, allowlist thuvienphapluat.vn, giới hạn 8 MB/30s, kiểm HTML/UTF-8, hashes nguồn/toàn văn, UTC; parser giữ thứ tự Điều/Khoản/Điểm. | Chưa chạy nguồn live hoặc lưu evidence vào Content SQL; cần fields P0. |
| P02 | Giữ index gate mặc định tắt; lập nhu cầu Sequence/Point/version/evidence/citation-eligibility API. | Hai contexts, SQL query adapter, index/deactivate/recovery và cross-service eligibility chưa có. |
| P03 | File bank không còn là runtime source: production bank đọc/ghi trả 503 chờ SQL. Thêm preflight manifest thuần, không ghi file/DB, hash bao gồm source/profile/keys/assets/animation mappings. | Không tự tạo entity/context/migration; SQL bank chưa có trên nền docs. |
| P04 | Giữ APIs/questions/templates hiện có, protected Admin preflight/capabilities; transport và yêu cầu query được ghi rõ cho owner schema. | Chưa có server-only pool endpoint vì auth contract của service caller chưa chốt; không mở key cho User. |
| P05 | Exact-host HTTPS animation validator ở backend/frontend; trang animation tĩnh theo step + đóng gói scenario có version/ID/source; component review link; fixture có nhãn. | Chưa có nguồn bank/profile hay hosting/domain được chọn, chưa deploy hoặc có ExplanationAnimationUrl thật. |
| P06 | UI Admin kiểm tra manifest/evidence độc lập SQL; chỉ rõ trạng thái chờ lưu, xem hash/Điều/Khoản/Điểm; giữ UI thư viện. | SQL bank, Practice/Progress UI và Worker cron integration còn phụ thuộc P0/owner modules. |

Không sửa BusinessObject entities, DataAccess contracts/DbContext/mappings/migrations/model snapshots hoặc shared Program.cs trong lượt C2 này. Không thêm bảng RefreshTokens/ViolationLogs/UsageReports; không thay auth hoặc khôi phục Kafka quota.

## API mới

Tất cả dưới `/api/admin/content-previews`, cần JWT role Admin:

- `GET /capabilities`: preview sẵn sàng, `canPersistBank=false`, `persistenceStatus=PendingSqlContract`, animation host allowlist. Đây là trạng thái module, không chứng minh SQL đã tồn tại.
- `POST /question-banks`: `{ "bank": <legacy typed manifest>, "animations": [{ "questionId": "GUID", "explanationAnimationUrl": "https://<approved-host>/lesson.html" }] }`, tối đa 10 MB. Trả issues theo path/hash/counts. `canImport` chỉ nói validation đạt, không nói persistence đã sẵn sàng. Endpoint không lưu/publish và không fetch URL ảnh/animation.
- `POST /legal-source`: `{ "sourceUrl": "https://thuvienphapluat.vn/van-ban/...aspx" }`. Trả canonical URL, UTC, hashes, số hiệu, title, text, ordered chunks. Preview không đặt Verified/active và không index Qdrant.

Nguồn trả redirect hoặc URL có query/fragment/credentials/path traversal bị chặn. Upstream lỗi → 502, timeout → 504, request cancellation truyền xuyên. Chặn media type không phải HTML, invalid UTF-8 và quá 8 MB.

## Cấu hình / UI

`Content__AnimationAllowedHosts__0=<host chính xác>` là cấu hình server (mặc định rỗng). Không wildcard hay lấy allowlist từ request. URL cần HTTPS/default port, path `.html` hoặc `/`, không query/fragment/credentials, không encoded traversal. Ví dụ host trong tests là `animations.example.org`, **không phải hosting đã deploy**.

`Content__CrawlJobStoragePath` tùy chọn lưu private trạng thái crawl operational (mặc định `Presentation/App_Data/crawl-jobs`); đây không phải canonical bank. `Content:BankStoragePath` không còn điều khiển bank production. Legacy file adapter chỉ dùng tests/chuyển dữ liệu, không đăng ký fallback. `Content:EnableVerifiedIndexing` vẫn false cho tới khi đủ contract version/deactivate và boundary checks C2.

UI preview host có tab **Kiểm tra nội dung**. Gói JSON trần legacy hoặc envelope `{bank, animations}` đều được xem trước; nút lưu SQL hiện disabled rõ lý do. `ContentPreflight` dùng authenticated API client của shell; component Admin không thay auth backend.

`ExplanationAnimationLink` chỉ hiển thị khi `canReview` và URL đạt allowlist; đây là UX guard. Server phải kiểm tra owner/submission trước khi trả URL, vì trang animation có thể chứa lời giải. Không tích hợp vào active questions DTO.

## Animation artifact

`content-animations/` là static renderer thuần HTML/CSS/ES modules, không cần bundler, không fetch provider hay nhận answer key từ query. Có Play/Pause/Previous/Next/Reset, pause khi tab ẩn, reduced-motion và Vietnamese labels. Scenario gồm questionId, bankVersion, sourceUrl, title/description và steps `{caption,x,y,rotation}`. Renderer dùng textContent, không thực thi HTML từ JSON.

```powershell
node --test tests/content-animation.test.mjs
node scripts/package-content-animation.mjs path/to/reviewed-scenario.json
# Chỉ kiểm thử fixture (không coi là demo dữ liệu chính thức):
node scripts/package-content-animation.mjs content-animations/scenario.example.json --allow-fixture
```

Packager validate rồi xuất dưới `artifacts/content-animations/<SHA256>/` (gitignored), không deploy. Host toàn bộ thư mục trên static hosting HTTPS, kiểm URL live rồi mới lưu ExplanationAnimationUrl theo schema Vương. Không chỉ upload mỗi index.html: cần CSS/JS/scenario.json cùng thư mục. Fixture không được đóng gói nếu thiếu cờ `--allow-fixture`.

## Kiểm thử lượt C2

- `dotnet test tests/Content.Tests/Content.Tests.csproj --no-restore`: **51 passed**, gồm tests cũ và preflight/url-policy/evidence/cancellation/size/UTF-8/Admin/production-no-file-bank.
- `node --test tests/content-animation.test.mjs`: **4 passed** (Node 24 hiện báo experimental type stripping khi đọc utility TS; không có dependency mới).
- `npm run build` trong web: TypeScript/Vite thành công.
- Browser kiểm tra packaged fixture, nút Bước sau chuyển đúng 1/3 → 2/3 và caption.

Chưa chạy live source/SQL/Gateway/Kafka/Qdrant/Redis/Worker hoặc deploy animation. Không chạy migration-on-startup hay generate migration. Build/model-check legacy không chứng minh hai DB đã có. Xem đề xuất bàn giao cụ thể tại [PHUC-P0-CONTENT-REQUIREMENTS.md](PHUC-P0-CONTENT-REQUIREMENTS.md).
