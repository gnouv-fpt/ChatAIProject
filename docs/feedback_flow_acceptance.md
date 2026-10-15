# Luồng tư vấn học tập và kiểm chứng theo góp ý Lab 2

## Luồng demo có thể chạy

1. Trong **Cài đặt**, lưu mục tiêu môn học, cách học ưu tiên, mức ưu tiên và mục tiêu dài hạn. Có thể để trống các trường chưa biết và bổ sung sau.
   Có thể tự xác nhận học kỳ hiện tại; nếu bỏ trống, ứng dụng chỉ suy ra kỳ từ môn đang học hoặc ghi rõ đó là kỳ gần nhất có kết quả.
2. Trong **Bảng điểm**, nhập hoặc xác nhận điểm và môn đang học. Dữ liệu đã xác nhận được lưu trên thiết bị.
3. **Trang chủ** hiển thị tín chỉ, GPA, môn đã hoàn thành, học kỳ và môn đang học. Chọn một môn ở phần kỳ tới hoặc mở **Lộ trình → Kỳ tới**.
4. **Lộ trình** phân biệt môn đã hoàn thành (kèm điểm), đang học, đủ tiên quyết, còn thiếu tiên quyết, và mã tiên quyết chưa xác minh. Chọn môn để mở chi tiết.
5. **Chi tiết môn** có ba tab: chuẩn đầu ra, điều kiện môn học, tiêu chí đánh giá. Xem gợi ý có nguồn, hỏi trợ lý theo mục tiêu đã lưu, hoặc quay sang cập nhật điểm rồi hỏi lại.
6. Trong **Trợ lý**, dùng nút **Các phiên tư vấn** để mở lại câu hỏi cũ theo tag nội dung và ngữ cảnh môn/chương trình; nút **Phiên tư vấn mới** tạo một phiên riêng.

Trên cửa sổ rộng, các mục chính nằm ở thanh điều hướng bên trái; trên điện thoại, chúng nằm ở thanh điều hướng phía dưới.

Kết luận “đủ tiên quyết” chỉ dựa trên môn đã đạt trong bảng điểm và mã tiên quyết có trong dữ liệu FLM. Nó không xác nhận lịch mở lớp, quy định đăng ký, hay điều kiện của trường du học.

## Kịch bản think aloud cần chạy với sinh viên thật

| Nhiệm vụ không hướng dẫn thao tác | Quan sát cần ghi | Thành công khi |
| --- | --- | --- |
| Tìm môn có thể học kỳ tới sau khi nhập kết quả học | Đường đi, thời gian, điểm dừng, lời nói của sinh viên | Tự chỉ được ít nhất một môn và giải thích căn cứ tiên quyết |
| Xác định vì sao chưa đủ điều kiện học một môn có tiên quyết | Có tìm thấy tab điều kiện và mã còn thiếu không | Nói đúng mã tiên quyết còn thiếu hoặc nhận ra mã cần xác minh |
| Đổi mục tiêu từ qua môn sang điểm cao và xin tư vấn lại cùng một môn | Có thấy chỗ đổi mục tiêu và nhận ra chiến lược thay đổi không | Nêu được khác biệt trong hành động học, không nhầm dữ kiện FLM với thông tin tự khai |
| Cập nhật điểm rồi quay lại tư vấn, sau đó tìm phiên cũ | Có giữ ngữ cảnh môn và lịch sử không | Mở lại được phiên trước và nhận ra tư vấn mới dựa trên dữ liệu mới |

Ghi lại số người tham gia, chương trình/bảng điểm họ tự nguyện dùng, thời gian từng nhiệm vụ, lỗi quan sát được và câu nói nguyên văn có đồng ý ghi nhận. **Chưa có buổi kiểm chứng với sinh viên thật trong lần triển khai này.**

## Kiểm tra tự động trong lần triển khai này

- `flutter test`: 25 ca đạt, gồm luồng từ tiến độ đến môn kỳ tới và điều kiện tiên quyết, lưu hồ sơ và lịch sử chat.
- Backend unittest trọng điểm: 11 ca đạt, gồm lập kế hoạch kỳ tới, tư vấn theo mục tiêu và dữ kiện môn học.
- `flutter analyze` trên các file của luồng mới: không có issue. Phân tích toàn dự án còn 9 thông báo mức info ở widget/test cũ.
- APK debug build thành công. Đây là bằng chứng build, chưa thay cho thử nhập ảnh bảng điểm thật và kiểm chứng với sinh viên.

## Ranh giới dữ liệu

- Điểm, GPA và trạng thái học: bảng điểm đã xác nhận trên thiết bị, tính bằng code.
- Kỳ và tiên quyết: dữ liệu chương trình FLM; mã tiên quyết ngoài danh mục phải hiện “cần xác minh”.
- Mục tiêu, ưu tiên, cách học và nghề: sinh viên tự khai, dùng để điều chỉnh cách tư vấn.
- Điều kiện du học, chuẩn tuyển dụng, lịch mở lớp: chưa có nguồn; trợ lý phải yêu cầu thêm tiêu chí trước khi kết luận.
