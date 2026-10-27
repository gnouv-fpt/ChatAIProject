# Lời thuyết trình Lab 2 FLM Student Assistant

**Bổ sung sau feedback 26/10:** dùng [Design System một trang](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-558) và [mapping persona](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-543). Khi demo Home, dừng chỉ hoàn thành/còn lại/đang học và dữ liệu gốc trước khi click. Mỗi bước ra quyết định dành khoảng 5–8 giây để giải thích; loading 3 giây trong Figma là mô phỏng. Số màn liên quan P01/P02/P03/P04 là 8/7/5/6; không đổi chúng thành tỷ lệ đáp ứng nhu cầu. Cách tính và phần chưa kiểm ở [phiếu chung](ux-feedback-validation.md). Link Canva dưới đây chưa được chỉnh trong lượt 27/10; trình bày bằng board Figma bổ sung, không nói deck đã được cập nhật.

[Mở bộ 12 slide trên Canva](https://www.canva.com/d/xuF6mntcHFgFXF6).

Thời lượng dự kiến 8–10 phút, sau đó demo Figma. Nội dung dựa trên tài liệu và ảnh xuất Figma đang có trong workspace ngày 22/10/2026. Không có số liệu phỏng vấn hoặc kết quả usability test để công bố.

## Slide 1 Hành trình thiết kế

FLM Student Assistant hỗ trợ sinh viên lập kế hoạch học tập theo chương trình, kết quả và mục tiêu cá nhân. Câu hỏi nhóm muốn giải quyết là: sinh viên đang ở đâu, kỳ tới nên cân nhắc môn nào, và nên học môn đó thế nào? Em sẽ trình bày quá trình từ phân tích vấn đề và persona đến user flow, wireframe, style guide, mockup và prototype Figma. Một tình huống xuyên suốt là sinh viên Hoàng Nam muốn chọn môn kỳ tới nhưng chưa hiểu rõ chuỗi tiên quyết.

## Slide 2 Vấn đề và nguồn nghiên cứu

Trong tài liệu phản hồi Lab 1, giảng viên yêu cầu sản phẩm thể hiện rõ tiến độ học tập, quan hệ môn và tư vấn theo ngữ cảnh. Nhóm đối chiếu các nhận xét này với chương trình học và luồng sử dụng hiện tại. Từ đó, nhóm đặt ba câu hỏi: người học gặp khó ở bước nào, thông tin nào giúp họ tin vào tư vấn, và họ phục hồi thế nào khi thiếu điểm hoặc nhập ảnh thất bại? Hiện chưa có biên bản phỏng vấn hay khảo sát sinh viên, nên các nhận định về nhu cầu được trình bày là giả thuyết cần kiểm chứng.

## Slide 3 Người dùng và persona

Primary persona là Hoàng Nam, sinh viên năm ba ngành phần mềm, cần hiểu tiên quyết và tiến độ để không chậm kế hoạch. Thu Trang đại diện cho sinh viên đầu chuyên ngành, chưa có bảng điểm và cần giải thích thuật ngữ. Minh Tuấn đại diện cho nhu cầu học lại, cải thiện GPA và kiểm soát dữ liệu cá nhân. Giảng viên là supporting persona, giúp đặt yêu cầu kiểm tra phép tính và nguồn tư vấn. Bộ persona do nhóm cung cấp chưa kèm hồ sơ nghiên cứu, nên em dùng nó để định hướng thiết kế, chưa xem là mô tả đã được xác nhận cho toàn bộ sinh viên.

## Slide 4 Từ nhu cầu đến quyết định UX

Nhóm chuyển từng nhu cầu thành quyết định có thể nhìn thấy trên giao diện. Vì người học khó biết vị trí hiện tại, Trang chủ ưu tiên tiến độ và bước tiếp theo. Vì quan hệ môn khó đọc, Lộ trình dẫn tới Chi tiết môn có điều kiện tiên quyết. Vì lời khuyên dễ thiếu căn cứ, trợ lý nhận ngữ cảnh môn và cần nêu nguồn hoặc giới hạn dữ liệu. Nếu chưa có bảng điểm, hệ thống không kết luận người học đủ điều kiện. Tiêu chí thành công đề xuất là sinh viên tự chọn được một môn cần cân nhắc và giải thích đúng lý do; nhóm chưa có số đo thực tế cho tiêu chí này.

## Slide 5 Information architecture

Ứng dụng được chia thành năm màn gốc: Trang chủ, Lộ trình, Trợ lý, Bảng điểm và Hồ sơ. Ba màn con là Chi tiết môn, Xác nhận bảng điểm và Chương trình đào tạo. Cách tổ chức này cho phép người dùng bắt đầu từ mục tiêu quen thuộc, rồi mở thông tin chi tiết khi cần. Trên mobile, năm màn gốc dùng thanh điều hướng dưới; màn con có Back về nơi đã mở. Nhóm giữ tám đích điều hướng khác nhau, không tính dialog hay các trạng thái loading, empty, error thành màn mới.

## Slide 6 Ba user flows

Flow thứ nhất đi từ kết quả học đến tiến độ, môn kỳ tới và điều kiện tiên quyết. Flow thứ hai đi từ chương trình tới chi tiết môn và tư vấn theo mục tiêu. Flow thứ ba xử lý nhập bảng điểm: khi ảnh hoặc API lỗi, người dùng có thể thử lại, nhập tay và sửa trước khi lưu. Các flow có cả happy path lẫn nhánh thay thế. Tài liệu đã mô tả ba flow, còn prototype cần được chạy nghiệm thu từng đường để xác nhận không có ngõ cụt.

## Slide 7 Wireframe

Ở bước wireframe, mục tiêu là quyết định thứ tự thông tin và vị trí hành động. Trang chủ cần giúp người học nhìn thấy tiến độ trước khi khám phá sâu. Bảng điểm phải giải thích được trạng thái chưa có dữ liệu và cho thấy hành động nhập dữ liệu. Chi tiết môn chia thành chuẩn đầu ra, điều kiện và đánh giá, rồi cho hỏi trợ lý theo môn. Khi trình bày, em mở một wireframe và mockup của cùng màn để giải thích bố cục đã được giữ hoặc thay đổi thế nào. Chỉ dùng cặp đối chiếu có thật trong Figma.

## Slide 8 App style guide

Style guide thống nhất màu, chữ, khoảng cách, bo góc, độ nổi và các trạng thái. Primary hiện dùng xanh #1565C0, accent #B34700, nền sáng và chữ tối để phân biệt vai trò nội dung. Trong Figma đã có variable, text style và chín nhóm component: Button, Text field, Card, Navigation, App bar, Dialog, Loading, Empty và Error. Thư viện đã xử lý 30 variants. Bước tiếp theo là đối chiếu việc dùng instance và token trên từng màn; chất lượng thư viện chưa tự chứng minh mọi màn đều đạt accessibility.

## Slide 9 Mockup

Mockup bổ sung màu, chữ, nội dung và trạng thái cụ thể vào cấu trúc wireframe. Ảnh giao diện trong bài được xuất từ Figma thật. Nhật ký ghi nhận 11 frame mobile, nhưng trong đó có biến thể trạng thái, nên nhóm cần đối chiếu từng frame với tám màn S01 đến S08 trước khi khẳng định đủ số màn. Việc kiểm tra tiếp tục tập trung vào hierarchy, chữ, vùng chạm và bố cục ở 360 và 412 dp.

## Slide 10 Critique và vòng lặp

Một ví dụ thay đổi đã có bằng chứng là đồng bộ màu Figma với màu ứng dụng, sửa Button và Text field để thể hiện đúng trạng thái, rồi bổ sung các nhóm component còn lại. Các ảnh trước và sau giúp giải thích thay đổi cụ thể. Nhóm cũng có danh sách critique từ source và ảnh giao diện, nhưng chưa gọi đó là kết quả user testing. Theo rubric, phần Google Stitch vẫn cần prompt, output và ba vòng lặp khác mục tiêu. Hiện chưa có các bằng chứng này, nên em giữ chúng ở trạng thái chưa hoàn tất.

## Slide 11 Figma prototype

Prototype cần chứng minh một người dùng đi từ điểm bắt đầu tới mục tiêu qua thao tác rõ ràng. Em sẽ chọn ba starting point tương ứng ba flow, kiểm Back, overlay của dialog và chuyển từ loading sang kết quả. Với flow nhập ảnh, cần trình diễn đường lỗi rồi nhập tay để phục hồi. File hiện có reactions và starting points, nhưng việc đếm các liên kết chưa chứng minh flow chạy hoàn chỉnh. Chỉ công bố flow đã pass khi đã thao tác và ghi lại kết quả thực tế.

## Slide 12 Kết luận và handoff

Chuỗi thiết kế của nhóm có thể truy ngược từ nhu cầu của Nam đến flow, wireframe, style guide, mockup, prototype và tài liệu triển khai. Handoff mô tả layout, component, state, interaction, navigation và constraint cho từng màn, kèm mapping sang Flutter. Hiện đã có persona, IA, flow, screen spec và các phần thiết kế Figma. Những việc còn mở là nghiên cứu sinh viên thực, bằng chứng Stitch, nghiệm thu tám màn và ba flow, cùng QA 360/412 dp. Đây là các bước cần hoàn tất để chứng minh quá trình thiết kế đã được kiểm chứng.

## Kịch bản demo khoảng 5 phút

1. Mở Figma, giới thiệu User Flow, Wireframe, Final UI, Design System, Components và Prototype. Nếu mục nào đang là section, gọi đúng là section.
2. Theo Hoàng Nam: xác nhận mục tiêu và kết quả → Trang chủ → Lộ trình → Chi tiết môn → điều kiện và tư vấn.
3. Trình diễn nhánh thiếu dữ liệu và nhánh nhập ảnh lỗi → nhập tay → sửa → lưu.
4. Mở một component có variants, variable binding và một instance thật trên màn.
5. Mở handoff, chỉ ra cách một quyết định thiết kế được chuyển thành widget/state/navigation.

Nếu một đường tương tác chưa hoạt động, chỉ rõ màn và state đang có, không gọi nó là flow đã chạy thành công.
