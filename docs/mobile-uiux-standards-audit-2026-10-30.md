# Rà soát quy ước UI/UX mobile — 30/10/2026

## Kết quả ngắn gọn

**14/20 mục đạt trong phạm vi kiểm tra; 5 mục đạt một phần; 1 mục chưa kiểm chứng.** Nếu chỉ đếm mục đã xác minh đầy đủ trong checklist này: **70%**. Đây **không phải “đạt 70% WCAG”**, không phải chứng nhận tuân thủ, cũng không phải điểm thẩm mỹ. Các mục có trọng số bằng nhau chỉ để theo dõi công việc; checklist không bao phủ toàn bộ tiêu chí WCAG.

Phạm vi: Flutter mobile, giao diện sáng, dữ liệu kiểm thử. Các màn/khối được kiểm tra mới gồm Trang chủ, Lộ trình, Cài đặt, Đăng nhập, Chat, Chương trình học, Chi tiết môn, Khung tư vấn và Tin nhắn. Kiểm tra bổ sung sơ đồ, dialog kết nối, xác nhận xóa và bàn phím. Các luồng bảng điểm/điều hướng từ lượt trước được chạy hồi quy.

“Đạt” chỉ áp dụng cho luồng, trạng thái và kích thước có bằng chứng dưới đây; không suy rộng thành mọi dữ liệu và mọi thiết bị.

## Cơ sở đối chiếu

- [Android accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps): vùng chạm khuyến nghị tối thiểu **48×48 dp**; tương phản chữ nhỏ **4,5:1**, chữ lớn **3:1**.
- [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing): đo kích thước và nhãn điều khiển qua cây semantics; kiểm tra thêm bằng công cụ và trình đọc màn hình thật.
- [Flutter UI design and styling](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling): giao diện thích ứng với cỡ chữ của người dùng.
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/) và [giải thích tương phản](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html): đối chiếu nội dung, điều khiển, nhãn và phản hồi. Mốc web 24 CSS px của SC 2.5.8 không được dùng thay cho khuyến nghị native 48 dp.

Các mục phân cấp thị giác, hành động chính và điều hướng là quy ước thiết kế được đánh giá nội bộ; không gán chúng thành điều khoản WCAG bắt buộc.

## Checklist 20 mục

| # | Tiêu chí | Kết quả | Bằng chứng / giới hạn |
|---|---|---|---|
| 1 | Phân cấp tiêu đề, nội dung, nhóm thông tin | Đạt | Trang chủ ưu tiên tiến độ; nhóm thống kê và khám phá tách nhau; rà ảnh giao diện. |
| 2 | Hành động chính dễ nhận ra | Đạt | Một nút lưu bảng điểm chính; mở lộ trình nổi bật; hành động phụ dùng kiểu nút khác. |
| 3 | Điều hướng có nhãn và vị trí nhất quán | Đạt | Thanh điều hướng chính, các tab chương trình và đường mở chi tiết hoạt động trong kiểm tra hồi quy. |
| 4 | Có cách đóng/quay lại rõ trong các hộp thoại được kiểm tra | Đạt | Thêm nút đóng khung chat môn học, danh sách sơ đồ và thông tin môn; kiểm tra mở/đóng. |
| 5 | Bố cục thích ứng tại các kích thước đã chọn | Đạt | Bộ hồi quy 360/412/1280 dp; sửa hàng mã môn/tín chỉ tràn khi phóng chữ. |
| 6 | Vùng an toàn, xoay ngang, tai thỏ/thanh hệ thống | Một phần | Đã thêm SafeArea cho sheet; chưa nghiệm thu các cấu hình phần cứng và xoay ngang. |
| 7 | Nội dung vẫn dùng được khi tăng chữ 200% | Đạt | Chín màn/khối thử ở 360×640, 1×/2×; Lộ trình cuộn được và chip tự xuống hàng. Bảng điểm có bài kiểm tra riêng. |
| 8 | Vùng chạm tối thiểu 48×48 dp | Một phần | Các điều khiển trong viewport mẫu vượt phép đo; chưa quét toàn bộ phần cuộn và mọi trạng thái. Đã sửa nút gửi, sao chép, kết nối, chip, breadcrumb. |
| 9 | Nút có tên/nhãn cho công nghệ hỗ trợ | Một phần | Kiểm tra semantics của mẫu đạt; thêm nhãn gửi, sao chép, bỏ ảnh. Chưa kiểm tra toàn bộ thứ tự đọc và toàn bộ cây semantics. |
| 10 | Tương phản chữ đủ rõ | Một phần | Chín cặp màu trạng thái/chữ chính đạt ≥4,5:1; chưa đo mọi cặp màu được dựng trên mọi màn. Nhãn PE: 3,46:1 → 5,02:1. |
| 11 | Không chỉ dùng màu để truyền trạng thái | Đạt | Nhãn đạt/chưa đạt/đang học; trạng thái kết nối có chữ và biểu tượng; sơ đồ có danh sách và quan hệ tiên quyết bằng chữ. |
| 12 | Ô nhập trong luồng kiểm tra có nhãn rõ | Đạt | Bổ sung nhãn tìm môn và câu hỏi; địa chỉ máy chủ có nhãn tiếng Việt. |
| 13 | Dữ liệu sai có hướng dẫn sửa | Đạt | URL không hợp lệ giữ dialog mở và chỉ cách sửa; bộ kiểm tra nhập điểm, tín chỉ, mã môn vẫn đạt. |
| 14 | Có phản hồi tải/lưu và chặn gửi lặp | Đạt | Các trạng thái hiện có trong chat/bảng điểm được giữ; nút gửi/lưu bị vô hiệu khi đang xử lý. Kết luận từ code và hồi quy, không đo tốc độ dịch vụ thật. |
| 15 | Có hướng xử lý khi rỗng/lỗi | Đạt | Retry dữ liệu chương trình; OCR lỗi có nhập thủ công; không tạo số liệu chương trình giả. |
| 16 | Xác nhận thao tác xóa dữ liệu trong luồng kiểm tra | Đạt | Khung tư vấn yêu cầu xác nhận xóa; hủy giữ nguyên tin nhắn. Luồng xóa bảng điểm được hồi quy. |
| 17 | Bàn phím không che thao tác nhập/gửi | Một phần | Khung tư vấn môn học qua bài thử 360×640, chữ 1,3×, bàn phím giả lập cao 280 dp; chưa kiểm tra mọi IME, chiều ngang và mọi form. |
| 18 | Có lựa chọn thay cho thao tác chính xác trên sơ đồ | Đạt | “Danh sách môn” dùng cùng tập môn đang hiển thị; chọn môn để đọc tiên quyết/phụ thuộc và mở hành động tương ứng. |
| 19 | Tôn trọng yêu cầu giảm chuyển động ở phần tùy biến đã sửa | Đạt | Sơ đồ chuyển sang bố cục tĩnh khi disableAnimations; chat bỏ cuộn hoạt ảnh. Có bài kiểm tra riêng cho sơ đồ. |
| 20 | Hoàn thành tác vụ với TalkBack/VoiceOver thật | Chưa kiểm chứng | Semantics test không thay thế thao tác thực tế bằng trình đọc màn hình trên thiết bị. |

## Đã sửa thêm trong lượt này

1. **Lộ trình:** bỏ chiều cao cố định làm chip còn 42 dp; cho bộ lọc/nội dung cuộn chung; sửa tràn dọc 73 px khi chữ 200%; đổi bộ chọn cách xem sang Wrap để không cắt nhãn.
2. **Chat:** nút sao chép từ biểu tượng chạm 13 px thành IconButton 48 dp có tên; nút gửi từ 44 lên 48 dp; bổ sung nhãn gửi/bỏ ảnh, tăng vùng chạm gợi ý và nhập câu hỏi.
3. **Kết nối:** thông báo tiếng Việt dễ hiểu; bỏ trạng thái “Resilience Mode” dễ gây hiểu nhầm; dialog cuộn được, có kiểm tra định dạng URL và lỗi ngay tại ô nhập.
4. **An toàn thao tác:** khung tư vấn có xác nhận trước khi xóa hội thoại; hủy không làm mất dữ liệu.
5. **Bàn phím:** chat môn học có safe area, chừa chỗ bàn phím và nút đóng; tạm ẩn gợi ý khi đang nhập. Bài thử điện thoại nhỏ tái hiện tràn 25 px trước sửa và đạt sau sửa.
6. **Môn học:** mã môn và tín chỉ xuống dòng khi cần; breadcrumb và hành động tư vấn được tăng vùng chạm.
7. **Màu/chữ:** nhãn PE tăng tương phản lên 5,02:1; thời gian tin nhắn và nhãn nguồn dễ đọc hơn; chip dùng font thống nhất; trạng thái tin nhắn có thể xuống dòng.
8. **Sơ đồ:** thêm danh sách môn, thông tin môn cuộn được và nút đóng; vô hiệu hóa hành động không có callback; hỗ trợ giảm chuyển động.

Các lượt trước đã sửa trang chủ, lưu bảng điểm, tab/bộ lọc chương trình, dashboard web, chat web và thẻ tài liệu mobile/tablet. Xem [tổng kết trước](uiux-summary-2026-10-30.md).

## Kiểm chứng và ảnh

- **42 bài kiểm tra đạt** ở bộ mobile audit + hồi quy UI liên quan; trong đó có **24 bài mới**. Chạy bổ sung với font Roboto thật và xuất ảnh: 24/24 đạt; sau chỉnh căn lề Lộ trình, chạy lại hai trường hợp Lộ trình đạt.
- Phép đo 48 dp dành cho điều khiển; loại trừ đoạn văn bản chỉ có thao tác chọn chữ bằng nhấn giữ. Không loại trừ ô nhập có thể chỉnh sửa hoặc nút. Đây là điều chỉnh được ghi rõ trong test, không tuyên bố nguyên bộ Android guideline đạt trên toàn app.
- Phân tích tĩnh Flutter sạch; build ASP.NET Core: 0 lỗi, 0 cảnh báo; không sửa nghiệp vụ hay hướng phụ thuộc các tầng.
- Ảnh dựng từ widget thật với dữ liệu mẫu, không phải ảnh tác vụ production:
  - [Lộ trình — chữ 200%](../evidence/ux/2026-10-30-mobile-audit/roadmap-2.0x.png)
  - [Khung tư vấn — chữ thường](../evidence/ux/2026-10-30-mobile-audit/contextual-chat-1.0x.png)
  - [Khung tư vấn — chữ 200%](../evidence/ux/2026-10-30-mobile-audit/contextual-chat-2.0x.png)
  - [Ô nhập phía trên vùng bàn phím giả lập](../evidence/ux/2026-10-30-mobile-audit/course-chat-keyboard-360.png) — vùng trống dưới ảnh đại diện phần bị IME chiếm, không phải bàn phím thật.

## Phần chưa chốt

Ưu tiên nghiệm thu tiếp: TalkBack/VoiceOver trên thiết bị; xoay ngang và vùng an toàn; quét kích thước/nhãn/độ tương phản của toàn bộ nội dung cuộn và các trạng thái khác. Không coi các mục này đã đạt chỉ vì build/test chạy thành công. Lượt này chưa kiểm tra Firebase/OCR/AI thật, chưa build APK mới; Figma chưa đồng bộ và thay đổi chưa push GitHub.
