# Luồng web và trang xem mô phỏng cho người học

**Cập nhật cuối 01/11:** learner đã lên [HTTPS public](https://content-animations.vercel.app/learn.html), đủ trang 486–600, giữ nguyên scenes/revisions đã duyệt. [Bàn giao deployment và kiểm tra public](ANIMATION-HTTPS-DEPLOY-2026-11-01.md). Phần mô tả “chưa deploy” bên dưới là lịch sử trước lượt phát hành; web/API/DB vẫn local.

Cập nhật dữ liệu local: 115 câu và 6 đề luyện đã vào SQL riêng, URL local đã nối và kiểm trọn luồng Gateway/web thật. Chi tiết: [LOCAL-LEARNING-115-2026-11-01.md](LOCAL-LEARNING-115-2026-11-01.md). Bản learner HTTPS bên ngoài chưa deploy.

Ưu tiên web theo yêu cầu người dùng; phần điện thoại để sau. Không thay scene, model, renderer hoặc revision trong 115 cảnh đã được duyệt.

## Luồng sử dụng

1. Đăng ký/đăng nhập trên web.
2. **Học luật** (`/hoc`): chọn ngân hàng/phiên bản đã xuất bản, xem câu hỏi và ảnh nguồn, chọn số câu để bắt đầu luyện. Hiện nút bắt đầu chuyển sang `/thi` và không nhận bộ lọc chủ đề/khoảng câu; UI thông báo khi còn bộ lọc.
3. **Luyện thi** (`/thi`): chọn ngân hàng/số câu/thời gian hoặc đề mẫu; tạo đề, trả lời, tự lưu, tiếp tục bằng mã đề. Đang làm bài không có lời giải hoặc link animation.
4. Nộp bài/hết giờ: server chấm; web mở `/ket-qua/:attemptId`, xem lựa chọn/đáp án/lời giải từng câu và nút mô phỏng từ snapshot server đã kiểm owner. Đã nối cả lịch sử. Bằng chứng và giới hạn bank/hosting: [WEB-EXAM-REVIEW-2026-11-01.md](WEB-EXAM-REVIEW-2026-11-01.md).
5. Mở mô phỏng của đúng câu bằng `ExplanationAnimationUrl`: ảnh gốc/3D, phát/dừng, tua, bước trước/sau, tốc độ, đáp án có nhãn và nguồn. Đóng tab/quay lại web để tiếp tục ôn tập.
6. **Tiến độ học** (`/tien-do`) có UI số liệu theo bộ câu hỏi, câu sai/chưa làm/lịch sử. Chưa kiểm tra lại tích hợp runtime các API này trong lần làm trang phát; không khẳng định mọi nút đã hoạt động trọn luồng.

Chat luật có trích dẫn và thư viện văn bản là các mục bổ sung, không bắt buộc để làm bài.

## Trang đã làm local

- `content-animations/learn.html`: trang phát dùng cho học, mặc định câu 486.
- `content-animations/q486.html` … `q600.html`: 115 đường dẫn HTML cố định. Sinh từ template bằng `python scripts/build-animation-learner.py`. Dùng đường dẫn thật vì validation hiện tại của URL animation không cho query/fragment.
- `content-animations/learn.js`, `learn.css`, `learn-icon.svg`: giao diện học, không có lưu review, ghi chú, nút duyệt hoặc xuất JSON. Dùng lại các renderer và CSS cảnh đã duyệt.
- Chỉ nạp câu có revision khớp `accepted-release.json`. Lỗi tải dữ liệu có nút thử lại; lỗi model có thể xem ảnh gốc và tải lại 3D. Không tự phát lúc mở trang.

Local: `http://localhost:8765/q544.html` (chỉ máy đang chạy server). Đây là trang lời giải nên hiển thị đáp án; không nhúng trang này trong bài đang làm.

## Phần còn lại của tích hợp web

1. Đã nối màn hình xem lại sau nộp và lịch sử, kiểm tra đúng/sai/chưa trả lời. UI dùng fixture riêng; API đã qua integration SQL/Redis/Kafka thật trên bank giả lập. Còn kiểm trọn luồng với bank/hosting thật.
2. Đóng gói/hosting HTTPS khi có yêu cầu deploy. Chưa có URL hosting thực trong lần này.
3. Đối chiếu bank/version + ID câu trong Content DB với số câu 486–600 rồi gắn URL HTTPS `/qNNN.html`. Không dùng số câu làm khóa DB hoặc gắn localhost vào dữ liệu phát hành.
4. Kiểm tra trọn luồng web với ngân hàng thật. Không thay schema/migration, không ghi DB trong lần làm trang phát.

## Kiểm tra

Browser desktop 1440×1080: kiểm tra câu 544 (POV), 486 (renderer gốc), 573 (người đi bộ), 577 (đoàn xe đạp); phát/dừng, bước sau, về đầu, ảnh gốc/3D hoạt động. Chọn câu 600, giới hạn câu cuối và Quay lại về 577 hoạt động. Cả 115 URL trả HTTP 200 và có đúng số câu trong entry HTML. Đã xem ảnh chụp giao diện 544 và 486.

Kiểm tra bằng response giả lập riêng trên browser: revision khác bản duyệt bị chặn, retry khôi phục sau khi gỡ giả lập; model HTTP 503 hiện lỗi và vẫn mở ảnh gốc được, sau gỡ lỗi mở lại 3D thành công. Đây là kiểm tra xử lý lỗi bằng giả lập, không phải sự cố hosting thật. Không có lỗi JavaScript/console ngoài hai HTTP 503 chủ động tạo. Script `output/playwright/check-animation-learner.cjs`, kết quả `output/animation-review/learner-web-check.json`, ảnh `output/playwright/learner-544.png` và `learner-486.png`.

Bộ 47 test animation và `node --check content-animations/learn.js` đã qua; log `tmp/animation-learner-tests.log`. SHA-256 scenes vẫn `60a92a16292baf6ff34466ca561808117a91faee0395e2d23813fec2ed07eff9`. Không kiểm tra mobile hoặc chạy lại toàn bộ C2/backend trong lần này vì không sửa các phần đó.

Git local trên `codex/prn-c2-integration-local`, HEAD `dbdcb5f`; chưa commit/push/PR/merge/deploy. Giữ nguyên thay đổi C2 có sẵn.
