# Phát hành animation HTTPS — 01/11/2026

**Cập nhật 02/11:** [bank HTTPS mới đã được import vào stack local](LOCAL-BANK-HTTPS-2026-11-02.md). Các bank/snapshot cũ vẫn giữ URL cũ. Không sửa file animation hoặc tạo deployment mới; nội dung dưới đây ghi nhận lượt phát hành 01/11.

Theo yêu cầu mới: **web/API/SQL/Redis/Kafka giữ local; riêng ảnh và animation được deploy lên Vercel hiện có**. Không tạo dịch vụ Render. Không commit, push, PR hoặc merge Git.

## Link sử dụng

- [Trang learner, mặc định câu 486](https://content-animations.vercel.app/learn.html).
- [Câu 486](https://content-animations.vercel.app/q486.html), [câu 544 góc nhìn người lái](https://content-animations.vercel.app/q544.html), [câu 573 người đi bộ](https://content-animations.vercel.app/q573.html), [câu 577 xe đạp](https://content-animations.vercel.app/q577.html), [câu 600](https://content-animations.vercel.app/q600.html).
- Đủ 115 đường dẫn `https://content-animations.vercel.app/q486.html` đến `q600.html`. Trang là lời giải sau làm bài, có đáp án và nguồn.
- Đã đưa cả 204 ảnh nguồn mới của câu 1–485 lên cùng host, tại `question-bank-600/`. Không có mô phỏng mới cho 1–485.

## Deployment và dữ liệu giữ nguyên

Project Vercel `content-animations`, ID `prj_hpwxazN6CDgyvTrXINN0vBP7PYtx`, owner `zipber199-6467s-projects`.

- Deployment cũ trên alias trước lượt này: `dpl_7poMLtxVtTBPKEGCSc1nxYnEu1t7`.
- Deployment mới: **`dpl_7mLuDf6HeYnNDDEhun55Qs8qE3gZ`**, trạng thái **Ready**; inspector: [Vercel](https://vercel.com/zipber199-6467s-projects/content-animations/7mLuDf6HeYnNDDEhun55Qs8qE3gZ).
- URL deployment: `https://content-animations-heckf6cej-zipber199-6467s-projects.vercel.app`. URL riêng này có deployment protection; dùng các link alias public bên trên để xem không đăng nhập.
- Upload từ thư mục `content-animations` bằng CLI, archive 59,8 MB, 762 file triển khai; không cần Git push. Không đổi gói dịch vụ hoặc tạo project mới.
- Đã tải candidate `scenes.json` và `q486.html` qua cơ chế xác thực chuẩn của Vercel CLI, đối chiếu byte với local, sau đó promote deployment và kiểm lại alias public.
- SHA-256 scenes giữ nguyên **`60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9`**. Đủ 115 revision khớp `accepted-release.json`.
- So SHA trước/sau: toàn bộ **763 file nguồn** ngoài metadata `.vercel` không thay đổi. Không chạy lại authoring, sinh scene, model, renderer hoặc revision.
- Giấy phép/nguồn model có trong `models/SOURCES.md`, `models/people/SOURCES.md` và vendor license đã đưa lên host.

## Kiểm tra trên public

`python -X utf8 scripts/check-animation-hosting.py --output artifacts/animation-publish/public-check.json` đã qua:

- 115 trang learner đúng byte của bản local.
- 735 file được tải và đối chiếu SHA-256 thành công, tổng 95.870.429 byte: bank/scenes/release, ảnh nguồn, ảnh nguyên câu PDF, nền, JavaScript/CSS/vendor, GLB và tài liệu nguồn của model.
- Kiểm tra dùng alias public qua HTTP thật, không dùng token đăng nhập, không chấp nhận redirect sang trang đăng nhập và không dùng business API giả lập.

Browser public kiểm sáu câu **486, 490, 544, 573, 577, 600**: canvas tải được, phát tiến thời gian, dừng giữ thời gian, bước sau, ảnh gốc, quay lại 3D; đúng số câu. Câu 600 không có câu tiếp. Chọn câu 577 chuyển đúng trang. Viewport 390 px không tràn ngang. Không ghi nhận JavaScript error trong lượt kiểm tra này. Đã xem trực tiếp ảnh desktop 486/544 và mobile 577.

Bằng chứng: `artifacts/animation-publish/public-check.json`, `source-before.json`, `browser-check.log`; script `output/playwright/check-animation-public-accepted.cjs`; ảnh `output/playwright/animation-public-*.png`. Đây là đối chiếu toàn bộ byte và kiểm thao tác có chọn mẫu, không phải duyệt hình ảnh lại cả 115 câu.

## Phạm vi local sau phát hành

Web vẫn ở `http://127.0.0.1:18080/hoc`, hai SQL DB local và catalog ngân hàng giữ nguyên. **Lượt này không ghi DB hoặc đổi URL trong các bank/snapshot đã import**; các link hiện có trong bank local vẫn trỏ máy chủ `localhost:8765`. Người học có thể mở các link HTTPS bên trên trực tiếp trên máy khác. Việc chuyển bank local sang dùng URL HTTPS là bước dữ liệu riêng, cần giữ identity/version/hash và lịch sử bài làm; không tự ghi đè package đã xuất bản.

Branch `codex/prn-c2-integration-local`, HEAD `dbdcb5f`. Các thay đổi source/dữ liệu của công việc trước vẫn local. Lượt này chỉ thêm script kiểm hosting và tài liệu phát hành; không thay các cảnh đã duyệt.
