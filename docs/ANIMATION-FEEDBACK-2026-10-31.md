# Bản sửa theo 115 ghi chú — 31/10/2026

Lượt sửa/rà tiếp theo ngày 01/11, gồm mũ fullface và toàn bộ danh sách feedback: [báo cáo hiện hành](ANIMATION-FEEDBACK-FULL-AUDIT-2026-11-01.md). Các quan sát và giới hạn bên dưới lưu trạng thái của lượt 31/10.

Đã đọc file người dùng cung cấp `E:/FPTU/2026FALL/PRN232/duyet-sa-hinh-486-600-2026-10-31.json`: 12 câu approved, 103 changes, 4 dấu ở câu 487. Bản sao nguyên vẹn: `output/animation-review/user-feedback-2026-10-31.json`. Bảng đối chiếu từng câu: `output/animation-review/feedback-repair-ledger.md` và JSON cùng tên.

## Thay đổi local

- Bỏ lựa chọn và renderer xe 2D khỏi trang duyệt. Link cũ `view=2d` chuyển về 3D. Còn ảnh gốc và chỉ dẫn để đối chiếu; 115 câu mặc định dùng chế độ 3D.
- 103 câu cần sửa dùng đường biên soạn riêng thay đường dò pixel ở giao điểm mũi tên. Đoạn thẳng giữ thẳng; chỉ bo góc tại chỗ rẽ, có tăng/giảm tốc, đường minh họa và xe dùng cùng tiến độ. Xe có lượt đi trong các sơ đồ giao lộ đi ra khỏi khung trước lượt sau.
- Câu 517: sửa mô tô đi trước, ô tô chờ. Câu 525: thêm lượt ô tô sau mô tô. Câu 520: sửa vị trí xe đạp và đường quay của xe B. Các hướng thay thế được phát độc lập.
- Bổ sung lượt di chuyển cho các câu trước chỉ khoanh vùng; giữ đứng yên xe bị cấm/phải dừng. Riêng 511/512 giải thích rõ đường đỏ là đường bị cấm, không phát xe đi trên đường đó.
- Sửa hộp/vị trí/hướng của nhiều mô hình góc nhìn người lái. Thêm người ngồi trên xe đạp, người đi bộ có khớp bước, đèn xi nhan, chùm đèn pha, cửa sau xe van; dây nối kéo ở 510/515/518.
- Câu 600 có đủ ba mô tô trong ảnh (hai xe phía sau, một xe xa), khớp rơ-moóc riêng, lượt chờ rồi đi tiếp. Câu 596 có rào trượt đóng và người gác đường.
- Giữ nguyên actors, steps, note, roadCalibration, learningMode, perspective và cleanBackground của cả 12 câu đã duyệt. Renderer chung có thay đổi nên revision mới vẫn yêu cầu kiểm tra lại; lưu cả trạng thái duyệt trước và ghi chú, không tự duyệt lại.
- Ảnh gốc không bị sửa. Điều chỉnh mask để giữ biển/đèn; nền mới `q573-v2.webp` và `q596-v1.webp` được tạo bằng built-in imagegen, chỉ xuất/resize bằng Pillow. Nền được tái tạo không phải pixel gốc được khôi phục.

## Kiểm tra và giới hạn

Lệnh: `node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs`.

Kiểm tra gồm SHA ảnh nguồn và tài sản, kịch bản 115 câu, đường chạy/pose hữu hạn ở từng bước, tua lặp xác định, thứ tự và xe phải chờ, lối ra khỏi khung, lưu ghi chú qua nhiều lần import, kịch bản 12 câu đã duyệt, và parse/rig các mesh GLB thật. Test GLB thay phần giải mã texture bằng texture 1 pixel trong Node: nó chứng minh hình học/khớp, không chứng minh texture/WebGL hay chất lượng hình ảnh.

**Đã kiểm tra trực quan cục bộ một phần; chưa nghiệm thu câu nào.** Trên trang local, trạng thái vẫn là `0 Đã duyệt / 0 Cần sửa / 115 Chưa duyệt`. Các quan sát sau chỉ là kiểm tra spot-check, không đổi trạng thái duyệt:

- 573, bước 2 tại khoảng giây 4 và 9: người đi bộ 3D đi vòng xuống phía trước xe con màu xanh; ở hai mốc đã xem không còn chồng lên xe.
- 510: dây kéo vàng nét đứt giữa xe tải và xe ba bánh nhìn thấy. 515: hai dây nối của nhóm ba xe nhìn thấy.
- 513: giảm kích thước xe con giúp lộ biển hơn, nhưng mép xe vẫn che một phần biển tròn; chưa thể kết luận đã sửa hoàn toàn.
- 547: ở khung mẫu, đèn giao thông hiện rõ và không bị xe che. 559: ở mốc 1 giây, đèn xi nhan bên phải xe sáng.
- 576: cửa sau xe van mở và xe đối diện xuất hiện trong bước chuyển động.
- 596: rào chắn trượt đỏ-trắng hiện rõ trên đường tại mốc khoảng 6 giây; chưa kiểm hết chuyển động liên tục.
- 600: hai mô tô xếp sau xe con và một mô tô ở xa đều có mặt; ở mốc 12 giây, đầu kéo/rơ-moóc khớp qua đoạn rẽ trong khung đã xem. Chưa kiểm hết toàn bộ đường chạy.

Các cảnh trên cần người dùng tự duyệt. Chưa rà đủ vị trí/hướng mọi model, mọi mốc chuyển động, mask biển/đèn, phối cảnh, giao diện mobile, đổi câu nhanh và trạng thái tải lỗi. Ở câu nhìn từ khoang lái, chuyển động xe của bạn hiện là chỉ dẫn đường trên ảnh cố định, chưa phải camera 3D chạy qua cảnh.

Chưa deploy bản sửa này. Bản production rev=5 vẫn là bản trước feedback. Không commit/push; HEAD `dbdcb5f`, nhánh local `codex/prn-c2-integration-local`, giữ nguyên các thay đổi C2 có sẵn.

## Tái tạo

```powershell
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/update-feedback-cleanplates.py
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/report-animation-feedback.py
node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs
python -m http.server 8765 --bind 127.0.0.1 --directory content-animations
```

Không dùng `build-animation-clean-backgrounds.py` cũ một mình: nó dựa vào bộ bounds cũ và không biết nền/rào chắn 596 mới; bước cập nhật feedback ở trên giữ baseline mask rồi bổ sung các vùng nguồn đã sửa.

Prompt hai ảnh mới: xóa riêng người áo trắng đang sang đường ở 573; xóa riêng rào chắn trắng đang trượt qua lòng đường và người gác đường ở 596. Giữ các người/vật còn lại, rào hai lề, biển, đèn, đường/vạch, khoang lái, góc chụp và tỷ lệ. Bản PNG gốc imagegen và mô tả lưu tại `scripts/update-feedback-cleanplates.py`; ảnh cuối nằm trong `content-animations/clean-plates/`.
