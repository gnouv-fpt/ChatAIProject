# Chốt bản animation đã được người dùng duyệt

**Cập nhật phát hành 01/11:** bản giữ nguyên 115 cảnh đã được deploy lên [learner HTTPS](https://content-animations.vercel.app/learn.html) theo yêu cầu người dùng. Deployment, hash và bằng chứng: [ANIMATION-HTTPS-DEPLOY-2026-11-01.md](ANIMATION-HTTPS-DEPLOY-2026-11-01.md). Các bước bên dưới ghi trạng thái trước phát hành; bank/DB local chưa đổi URL trong lượt deploy này.

JSON người dùng xuất lúc `2026-11-01T14:33:16.645Z` có đủ 115 số câu, tất cả `approved`, không thiếu/trùng hoặc lệch revision hiện tại. Đây là sự chấp nhận hình ảnh của người dùng, không phải tự duyệt bởi agent.

Bản gốc vẫn ở `E:/FPTU/2026FALL/PRN232/duyet-sa-hinh-486-600-2026-11-01.json`. Bản lưu cuối: `content-animations/bank-review/review-feedback-accepted-2026-11-01.json`. Trang local lấy cùng nội dung từ `review-feedback.json`, nên trình duyệt mới khởi tạo 115 Đã duyệt / 0 Cần sửa / 0 Chưa duyệt. Các bản review đầu vào v2/v3/v4 và ledger sửa giữ riêng làm lịch sử.

`content-animations/bank-review/accepted-release.json` ghi SHA của JSON duyệt và scenes, cùng revision đã duyệt của từng câu. Không sửa renderer hoặc sinh revision mới khi chốt; toàn bộ 115 cảnh và 428 bước giữ nguyên. Trạng thái draft trong công cụ authoring không phải trạng thái duyệt; không đổi nó sau khi duyệt vì sẽ tạo revision khác.

Các bước phát hành còn lại:

1. Đã làm trang phát web local `learn.html` / `q486.html`–`q600.html`, không kèm nút duyệt/ghi chú; có mở đúng số câu, phát/dừng/tua và ảnh gốc. Luồng sử dụng và phần tích hợp còn lại: `docs/ANIMATION-WEB-LEARNER-2026-11-01.md`.
2. Đóng gói các file runtime/model/nền cần thiết, kiểm tra đường dẫn trên hosting và quyền sử dụng nguồn. Chưa phát hành bản này.
3. Khi được người dùng cho phép, deploy để có URL HTTPS cố định. Localhost chỉ chạy trên máy hiện tại.
4. Gắn URL vào `ExplanationAnimationUrl` của đúng câu trong Content/Exam, đối chiếu số câu/ID/phiên bản ngân hàng; kiểm tra từ luồng học, kết quả thi và mobile. Không tự ghi vào DB hoặc giả định số câu chính là khóa DB.

Nguồn hình ảnh/kiểm tra kỹ thuật và giới hạn được ghi ở báo cáo v4. Chấp nhận local không chứng minh đã triển khai hosting, đã gắn DB, hoặc ngân hàng/đáp án được xác minh pháp luật độc lập.

Git vẫn `codex/prn-c2-integration-local`, HEAD `dbdcb5f`. Chưa commit/push/PR/merge/deploy. Các thay đổi C2 và animation sẵn có được giữ nguyên.
