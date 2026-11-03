# Bank local dùng tài nguyên HTTPS — 02/11/2026

**Cập nhật sau đó cùng ngày:** đã thêm profile thi thử hạng B theo quy tắc có nguồn, bookmark User SQL và kiểm AI/RAG thật trong stack local. Xem [C2 finalization local](C2-FINALIZATION-LOCAL-2026-11-02.md); các bank/hash/lịch sử trong báo cáo này vẫn được bảo toàn.

Đã nối ngân hàng 600 câu trong stack local với hosting đã phát hành `https://content-animations.vercel.app`. Web/API/SQL/Redis/Kafka tiếp tục chạy local; không tạo dịch vụ trả phí, không deploy thêm. Không sửa/tái tạo 115 cảnh đã duyệt.

Mở [web local](http://127.0.0.1:18080/hoc), chọn **600 câu CSGT 2025 · luyện tập local · ảnh/mô phỏng HTTPS**. Trong Luyện thi, chọn đề có hậu tố **HTTPS**. Hai bank cũ vẫn xuất hiện để giữ khả năng dùng lại và xem lịch sử; không tự chuyển URL trong snapshot bài làm cũ.

## Identity và dữ liệu

| Thành phần | Giá trị |
| --- | --- |
| Branch / HEAD | `codex/prn-c2-integration-local` / `dbdcb5f0c723757d39429a518e4d29f20a2adba4` |
| Content DB | `TrafficContent_WebLearning_57e824ae` |
| User DB | `TrafficUser_WebLearning_57e824ae` |
| Bank HTTPS mới / version | `8862fec1-9423-51c6-99f8-96bcc861dba4` / `1` |
| Package hash Content API | `3EB16626BCF0F84121853AF9681013D4CAD716912734777F113A951B12DA13E8` |
| Bank 600 local cũ / hash giữ nguyên | `a2fdea91-efe0-592e-9e2a-6b8a4a0fa069` / `C54645FD5DD27EE4846A0BC7A01D6C6892F6DAA85B38C79CAA65713A9AB7E590` |
| Bank 115 cũ / hash giữ nguyên | `aeabe38b-f3c7-5d52-82e6-0214b3b6d37c` / `1CA6EAF8B7D0363F6610AEB87A289BD77D1B9E280F3902E15E9A01CB0787DF8F` |
| Catalog sau import | 3 bank, 1.315 hàng câu hỏi, 18 đề, 475 template items |
| Đề HTTPS | `local-600-https-8862fec1-B-01` đến `B-06`, version `1` |

1.315 hàng gồm các gói 115 + 600 + 600; vẫn chỉ có 600 câu nguồn khác nhau. Bank mới dùng **319 ảnh nguồn HTTPS ở 318 câu**, **115 animation HTTPS** `q486.html`–`q600.html`. Câu 1–485 có `ExplanationAnimationUrl = null`.

`content-bank/csgt-2025-https/package.json` được tạo xác định từ toàn bộ gói nguồn đã kiểm chứng, origin HTTPS và mã edition `https-assets-edition-v1`. Namespace bank và ID từng câu mới, template code/IDs câu được remap. Version vẫn `1` vì đây là bank độc lập. Chạy lại giữ nguyên ID/hash. Builder không ghi đè file khác nội dung; verifier dựng lại từ PDF đã ghim và so toàn bộ gói trước khi importer ghi DB.

Chỉ thay identity/nhãn gói và URL tài nguyên. Prompt/options/key/lời giải/nguồn/metadata điểm liệt/thứ tự chọn câu giữ nguyên. Profile vẫn **luyện tập 80%, 30 câu/30 phút, không áp rớt điểm liệt**. Đây không phải profile thi GPLX chính thức. `localOnly=true` chỉ giới hạn nơi import/chạy API, tài nguyên ảnh/mô phỏng được phục vụ qua HTTPS.

Import dùng API admin hiện có, kiểm PID/cổng/DB riêng, kiểm nguồn và các conflict, import/publish bank rồi đề. Không UPDATE SQL hàng loạt, không sửa schema/migration, không ghi đè bank đã xuất bản. Các API là nhiều bước riêng; có thể chạy tiếp sau gián đoạn, không có transaction chung cho toàn quy trình.

## Chạy lại

```powershell
# Chỉ khi stack chưa chạy, dùng launcher hiện có:
pwsh -NoProfile -File scripts/start-c2-test-infrastructure.ps1
pwsh -NoProfile -File scripts/start-local-learning.ps1 -SkipBuild

python -X utf8 scripts/prepare-question-bank-https.py
python -X utf8 scripts/prepare-question-bank-https.py --verify
pwsh -NoProfile -File scripts/import-question-bank-600.ps1 -Https
python -X utf8 scripts/check-question-bank-600.py --https

# So hash toàn bộ hàng Content trước/sau một lượt importer chạy lại;
# đồng thời so các hàng cũ với baseline trước lần import HTTPS đầu tiên:
python -X utf8 scripts/check-https-bank-preservation.py --rerun-import
```

`-SkipBuild` dùng binary đã build trong `artifacts/local-learning/bin`; nếu source backend đổi thì cần build lại bằng launcher. Không chạy start lần nữa khi stack đang chạy. Hai migration histories được launcher kiểm explicit; lượt này báo **không có migration cần áp dụng**. Secrets/tài khoản test chỉ ở `artifacts` đã Git-ignore, không in hoặc đưa vào Git.

## Bằng chứng đã chạy

- Python `python -X utf8 -m unittest discover -s tests -p 'test*bank*.py'`: **9 qua**. Kiểm định danh mới/ổn định, remap templates, giữ nguyên nguồn và policy, URL sai bị chặn, các kiểm nguồn 600/115 có trước.
- `dotnet test tests/Content.Tests/Content.Tests.csproj --no-restore --nologo -v quiet`: **59 qua, 0 bỏ qua**. Không đổi C# trong phiên này.
- Prepare/verify và import chạy lại thành công. Một lượt kiểm riêng so hash **tất cả 1.315 câu, 6 categories, 18 templates, 475 template items** trước/sau rerun: không hàng nào đổi, không tạo thêm hàng.
- Baseline SQL trước lần import đầu tiên: **715 câu cũ, 6 categories, 12 templates, 295 template items và 9 ExamAttempts** giữ nguyên hash từng hàng, gồm nội dung snapshot lịch sử. Chỉ lưu ID/hash vào bằng chứng, không xuất nội dung tài khoản. Hash hai bank cũ và summary/template cũ cũng được API kiểm lại.
- **765 file** không đổi: 763 file nguồn animation ngoài `.vercel` và hai file gói 600 cũ. SHA scenes giữ nguyên `60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9`.
- Hosting public đọc lại **735 file / 95.870.429 byte**: khớp SHA local, gồm toàn bộ 115 learner pages, ảnh, scenes/models/renderer/vendor. Chỉ đọc hosting đã có; không phát hành deployment mới.
- Gateway/SQL thật trả đủ 600 câu, 60 cờ điểm liệt và 115 URL. Tải từ chính URL trong bank mới: **319 ảnh đúng SHA** và **115 learner HTML đúng số câu**; các câu 1–485 không có animation. API tạo đề 30 câu, autosave đủ 30 đáp án, cố ý sai một câu nguồn điểm liệt → **29/30, isPassed=true** theo policy luyện tập. Review/history bền vững và submit trùng giữ cùng attempt ID `6ed14875-68a6-4d5e-b111-19a3d3911240`.
- Browser thật qua Gateway: chọn bank HTTPS → đề B-01 HTTPS → key/lời giải ẩn khi làm → lưu một đáp án → rời trang/resume giữ đáp án/deadline → nộp **1/30** → review **29 chưa làm**, 9 link animation, 21 trạng thái chưa có mô phỏng → click mở popup HTTPS `q486.html`, canvas tải được → tiến độ học. Attempt `9dec4b38-bf7e-41ea-8825-82d81da04923`. Không giả lập business API; đường dẫn tạm để đọc credential file cục bộ được gỡ trước đăng nhập thật.
- Browser thư viện câu 301–303: đúng 3 câu, câu 301 đủ 4 options, ảnh HTTPS tải được, viewport 390 px không tràn ngang; không ghi nhận JavaScript error trong hai lượt browser. Đã xem trực tiếp ảnh review desktop/mobile và learner HTTPS câu 486. Đây là kiểm desktop/viewport mobile có chọn mẫu, không phải kiểm điện thoại thật hay duyệt lại 115 cảnh.

Bằng chứng máy đọc: `artifacts/question-bank-https/{before-import,import-result,live-check,public-check,preservation-before,preservation-check,rerun-check,browser-check}.json`, `browser-check.log`, `browser-library.log`, `rerun-import.log`. Script UI và ảnh: `output/playwright/*bankhttps*`.

## Runtime và phần riêng còn lại

Đầu phiên SQL đang chạy, web/API/Redis/Kafka chưa chạy. Docker Desktop không khởi động được do socket runtime `dockerInference` không truy cập được. Đã dừng các process Docker Desktop theo executable path, giữ thư mục socket cũ bằng cách đổi tên `C:\Users\LEGION\AppData\Local\Docker\run` thành `run.stale-20261102`, rồi mở lại Docker và launcher. Không reset Docker, xóa volume/container hay di chuyển dữ liệu DB. Thử đổi tên riêng socket không thành công; bước đổi tên thư mục runtime và khởi động lại đã khôi phục engine.

Web/API/Worker/SQL/Redis/Kafka được để chạy local khi bàn giao. Working tree vẫn chứa nhiều thay đổi từ các phiên trước và các file mới của phiên này; không stage, commit, push, PR, merge hoặc deploy. Không áp dụng profile thi chính thức khi chưa xác minh đúng hạng/ấn bản. AI/RAG, bookmark C2 và triển khai toàn hệ thống tiếp tục là việc riêng.
