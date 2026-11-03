# Bản duyệt phương tiện 3D và SVG 2D — 31/10/2026

Số lượng và model ở bản này đã được cập nhật tiếp trong [ANIMATION-GLB-ALIGNMENT-2026-10-31.md](ANIMATION-GLB-ALIGNMENT-2026-10-31.md).

Bản này thay số lượng và cách dựng trong bản duyệt 115 câu ban đầu; nguồn PDF và đáp án gạch chân không thay đổi.

- [Câu 486 — mô hình 3D](https://content-animations.vercel.app/review.html#q=486&view=3d)
- [Câu 486 — xe 2D thuật toán](https://content-animations.vercel.app/review.html#q=486&view=2d)
- Có thể đổi chế độ ở mọi câu; URL giữ chế độ xem khi chuyển câu và khi tải lại.

## Phạm vi triển khai

289 vị trí phương tiện được biên soạn trong 108 câu có mô hình 3D và hình SVG 2D tương ứng. Bao gồm xe con ngắn, mô tô, xe tải, xe khách/buýt, công an, cứu thương, chữa cháy, quân sự, xe đạp, xe ba bánh, van, container và tàu hỏa. Bổ sung các xe ngoài phương án được chọn để không biến mất khỏi tình huống. Các xe đỗ, dừng hoặc không có lượt đi vẫn đứng yên.

7 câu 545, 550, 570, 571, 590, 594, 596 tiếp tục dùng chỉ dẫn tại làn đường/khoang lái/người đi bộ thay vì dựng thêm xe ngoài tình huống. Xe của người lái được thể hiện bằng góc nhìn cabin trong ảnh, không đặt thêm một xe che phía trước camera. Các xe nhỏ trong phông cảnh/gương không phải toàn bộ đều được dựng lại; đây là bộ tọa độ phương tiện biên soạn cho lời giải, không phải kết quả phân đoạn mọi đối tượng trong ảnh.

Danh mục vị trí/hướng/kích thước: `scripts/animation_vehicle_catalog.py`. Recipe chuyển động: `scripts/author-animation-scenes.py`. Ảnh sa hình chéo và ảnh nhìn từ cabin có hai phép chiếu riêng; phép chiếu cabin giảm độ nhìn từ trên cao và giữ xe nhìn từ trước/sau có bề ngang hợp lý. Vẫn là căn chỉnh gần đúng theo từng vùng ảnh, không phải mô hình camera đo đạc.

## 2D dùng thuật toán gì?

`content-animations/review-sprites.js` tạo xe bằng các đa giác SVG từ kích thước thân, cabin, kính, bánh, cửa thùng và đèn. Không cắt ảnh xe, không gọi AI, không cần WebGL hoặc tải GLB trong chế độ 2D.

Hai chế độ dùng chung đường tâm và thời gian của từng recipe: đường Catmull–Rom centripetal hoặc đoạn thẳng; lấy mẫu theo chiều dài cung để chạy đều; hướng xe lấy theo tiếp tuyến; máy trạng thái bước quyết định xe nào chuyển động, chờ hoặc được đánh dấu vi phạm. Các đường và kết luận được biên soạn/đối chiếu nguồn trước; thuật toán không tự suy luật, nhận dạng biển hay lập đường hợp lệ từ một JPEG bất kỳ.

## Mẫu câu 486

Dùng so sánh đúng/sai độc lập, không gán thứ tự ưu tiên:

1. Chỉ đèn theo hướng đi và mũi tên có sẵn trong đề.
2. Xét riêng xe con, chạy đường minh họa đúng bằng nét xanh.
3. Lần lượt xét xe khách, xe tải, mô tô: giữ xe ở vị trí đầu; vẽ đường dự định bằng nét đỏ và đánh dấu sai theo đáp án nguồn. Không cho xe chạy hết một đường bị đánh dấu sai.
4. Trả xe về vị trí đầu ở mỗi lượt so sánh; kết luận chỉ xe con theo phương án được gạch chân trong PDF.

`learningMode: compliance`, `verdict` và `stopAt: 0` điều khiển trường hợp này. Các lượt xem không biểu thị quyền đi trước. Có 444 bước trong cả bộ sau khi bổ sung mẫu 486.

## Kiểm chứng

- Node: 7/7 test pass, gồm source hash, dải 115 câu, schema/path, phương tiện đỗ không tự chuyển động, camera car giữ dạng vùng, 486 chỉ chạy đường đúng, import/export và revision.
- Trình duyệt local: 115 câu ở 2D, 108 câu ở 3D; tổng 860 lần seek giữa bước, 289 sprite đúng số lượng, `errors: []`, `failures: []`. 223 ảnh scene được chụp trong `output/playwright/animation-v2`; sau đó căn lại các vùng xe có chữ A/B/C/D/E/G ở 543/548/554/566 và xe giữa giao lộ 528, kiểm tra trực tiếp cả năm câu.
- Chặn WebGL trong một tab mới: 2D câu 486 vẫn phát, đủ 6 sprite, 0 request GLB; bấm 3D hiện lỗi rồi quay lại 2D được. 390×844 không tràn ngang. Đây là kiểm tra lỗi giả lập, không phải benchmark mọi điện thoại.
- Chưa nhập/publish Content SQL, chưa duyệt thay người dùng. Giữ ghi chú cũ; thay đổi revision làm mất hiệu lực trạng thái Đã duyệt cũ.
- Vercel `dpl_HWoi4xZ5VNPPczwpoUq7MLYtthFS` READY; alias thật đã kiểm tra lại 115 câu/108 lượt 3D/289 sprite/860 lần seek: `errors: []`, `failures: []`. URL giữ chế độ khi chuyển câu và Back; reload ở 390×844 không tràn ngang; 0 câu được agent duyệt. Ảnh cloud tại `output/playwright/animation-v2/production-*.png`.

## Giới hạn

Ảnh gốc vẫn được giữ mờ bên dưới các mô hình. Tọa độ, hướng và kích thước cần tiếp tục duyệt từng câu. Xe chuyên dụng/xe SVG là hình đơn giản; container chưa có khớp rơ-moóc. Số lượng mô hình không chứng minh tất cả đường/giải thích đã được người dùng chấp thuận.

Git local: `codex/prn-c2-integration-local`, không commit/push; bảo toàn các thay đổi C2 khác.
