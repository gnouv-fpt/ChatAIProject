# Nền không có xe gốc cho chế độ 3D — 31/10/2026

108 câu có phương tiện 3D (trong 115 câu sa hình) dùng lớp nền xóa xe, ghép dưới mô hình GLB. 7 câu chỉ có góc nhìn/chỉ dẫn không cần lớp này. 106 ảnh nền phục vụ 108 câu: 486/503 và 554/566 dùng chung ảnh nguồn tương ứng.

Ảnh JPEG và ảnh nguyên câu trong PDF không bị ghi đè. Kiểm tra SHA-256 đối chiếu toàn bộ ảnh nguồn trong bank. Nút **Ảnh gốc**, **Chỉ dẫn trên ảnh** và **Xe 2D** không hiển thị lớp nền đã xóa xe.

## Tài sản và cách tạo

- Tài sản cuối: `content-animations/clean-plates/q*-v1.webp`, xuất đúng kích thước ảnh đề.
- Danh mục và hash: `content-animations/clean-plates/manifest.json`.
- Vùng xóa hiệu chỉnh: `content-animations/clean-plates/mask-overrides.json`.
- Bộ prompt chính xác theo từng tài sản: `output/animation-cleanplates/prompts.json`.
- Nhật ký từng ảnh: `output/animation-cleanplates/job-*.json`; giữ đường dẫn bản PNG gốc do công cụ tạo.
- Công cụ: **built-in imagegen**, không dùng CLI/API bằng key trong `.env`. Q490 tái sử dụng nền imagegen đã có trước đó.
- Pillow chỉ kiểm tra kích thước, xuất/downscale WebP và tạo bảng ảnh kiểm tra. Không dùng nó để inpaint.

Prompt yêu cầu xóa phương tiện bên ngoài, người ngồi trên xe và bóng xe; giữ góc máy, đường, vạch, biển, đèn, cảnh vật, người đi bộ, cảnh sát và khoang lái. Không thêm đảo cỏ, mũi tên hoặc làn đường. Bản Q486 đầu bị sinh thêm chi tiết nên đã sửa lại trước khi sử dụng.

Không dùng nguyên ảnh AI thay ảnh đề: CSS mask chỉ ghép nền vào vùng phương tiện. Q486/503 dùng polygon riêng cho 5 xe và vùng bảo vệ bảng đèn. Các vùng còn lại được đo từ pose ban đầu, hộp xe trong ảnh và hiệu chỉnh qua ảnh ghép. Rà soát đã sửa các hộp xe lệch rõ tại 510, 527, 551, 557, 575–578, 584, 586, 589 và xe phía trước tại 597; thêm xe sát bên phải tại 595.

## Trạng thái và giới hạn

Tất cả vẫn là **bản nháp để người dùng duyệt từng câu**. Phần mặt đường bị xe che không có pixel gốc để khôi phục chính xác; đó là nền tái tạo dùng minh họa. Chọn Ảnh gốc để xác minh nội dung đề. Không coi kết quả ghép nền là nghiệm thu luật, đường chạy hay phối cảnh của toàn bộ 115 câu.

Nền tải chậm không được ghi đè sang câu vừa chuyển. Nếu tải nền thất bại, vẫn xem được ảnh nguồn/mô hình và có thông báo rõ; chọn lại 3D sẽ thử tải lại. Đổi chế độ nhanh không nhân đôi model. Đổi revision khiến kết quả duyệt cũ cần duyệt lại, nhưng giữ ghi chú/dấu đánh vị trí.

## Kiểm tra local

- `node --test tests/animation-review.test.mjs`: 12/12 qua; gồm hash nguồn, tài sản riêng, 108 manifest, vùng mask và bảo vệ đèn.
- Browser thật: 108/108 câu tải và hiện đúng lớp nền; đối chiếu ảnh ghép khi ẩn GLB/SVG; kiểm tra nguồn ở các câu mẫu.
- Chặn request nền Q490: fallback giữ ảnh nguồn, ẩn nền lỗi; thử lại thành công.
- Trì hoãn request Q487 rồi chuyển Q486: câu cuối giữ đúng nền Q486 và 5 model.
- Đổi 3D/photo/3D liên tục: đúng 4 model ở Q487, không nhân đôi root.
- 390px: không tràn ngang, lớp nền 3D hiện đúng.

Scripts tái tạo metadata: chạy author để cập nhật hộp xe, build nền, rồi author để cập nhật revision:

```powershell
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/build-animation-clean-backgrounds.py
python -X utf8 scripts/author-animation-scenes.py
node --test tests/animation-review.test.mjs
```

Git: làm local trên `codex/prn-c2-integration-local`, giữ các thay đổi C2 có sẵn; không commit/push. Không sửa schema/migration/SQL trong việc này. Hosting được cập nhật riêng theo yêu cầu xem animation đã có của người dùng.

HEAD local: `dbdcb5f`. Vercel deployment: `dpl_7poMLtxVtTBPKEGCSc1nxYnEu1t7`, alias `https://content-animations.vercel.app`. 106 WebP tổng cộng 3.90 MB; 108 câu/284 mô hình. Mở bản 3D: https://content-animations.vercel.app/review.html?rev=5#q=486&view=3d.

## Kiểm tra hosting hoàn tất

Browser thật trên alias production: duyệt 115 câu, 108/108 nền sạch tải thành công, 106 tài sản nền, 284 sprite trong chế độ 2D, 416 lần tua ở các bước 3D. Không có lỗi JavaScript hay request tài sản thất bại. Chuyển về ảnh gốc ở 11 câu mẫu ẩn đúng GLB/SVG/nền tái tạo; mobile 390px không tràn ngang. Không tự duyệt câu nào (0 approved).

Kết quả máy đọc: `output/animation-cleanplates/production-verification.json`. Ảnh chụp production: `output/playwright/clean-production-*.png`. Lượt kiểm tra trước bị đóng browser giữa chừng nên không được tính là lượt đạt; số liệu trên đến từ lượt chạy mới hoàn tất.
