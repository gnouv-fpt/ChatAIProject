# Sửa model và căn đường — 31/10/2026

Thay bản khối thô được dùng ở lần duyệt trước. Link buộc mở lại tài liệu mới: https://content-animations.vercel.app/review.html?rev=4#q=486&view=3d

## Model

Thân xe tải, buýt, van, cứu thương, chữa cháy, quân sự, đầu kéo/rơ-moóc, xe đạp và đầu máy dùng chín GLB CC0 có chi tiết của Innerscene, không còn thân dựng bằng BoxGeometry. Xe con và mô tô tiếp tục dùng GLB đã có; công an dùng mesh xe con; xe ba bánh là bản thích ứng từ mô tô. Nguồn/license/hash download: `content-animations/models/vehicles-manifest.json` và `models/SOURCES.md`.

`review-detailed-fleet.js` chuẩn hóa đầu xe về +X dựa trên vị trí kính trước/đầu xe trong asset, bánh chạm Y=0; tách cụm bánh và gộp các mesh tĩnh theo vật liệu. Load theo loại xe đang xem, không tải cả bộ ngay lúc mở trang. Phụ kiện đèn/rider vẫn là lớp dựng thêm; không phải mọi chi tiết là hình quét từ ảnh đề.

## Sửa lệch

- Lỗi cũ: dùng chung góc chiếu câu 490 cho các ảnh khác, đồng thời hiểu vector hướng `[1,-0.5]` theo phần trăm rộng/cao thay vì pixel. Xe đứng yên vì vậy có thể lệch trục so với làn.
- `review-ground.mjs` dùng trục đường riêng theo từng ảnh trong `road-calibration.json`; nhóm ảnh cabin có phép chiếu riêng. Vector hướng tính bằng pixel, xe đứng chờ bám trục làn. Có đoạn vào làn ngắn để spline không quay mũi xe sớm về phía khúc cua khi đang ở vị trí đầu.
- Nội suy hình dạng quỹ đạo trong hệ pixel ảnh rồi mới chiếu xuống mặt đường. Đổi camera không được làm đường cong bị uốn sang hình dạng khác.
- `source-routes.json` giữ nét bám nguồn tách khỏi đoạn vào/ra của mô hình. Bộ dò dùng khoảng cách tới pixel đỏ và mốc đường cũ; bỏ đường thiếu độ phủ, quay ngược hoặc vòng thêm. Không tô đường ước lượng tại các đoạn chưa bám được nguồn; mũi tên gốc vẫn nằm nguyên trong ảnh.
- Câu 486 căn lại bằng mốc nhìn trực tiếp: xe con cua theo nét nguồn, hai xe tải và mô tô được đối chiếu riêng; ảnh này có 5 xe, không có xe con ở nhánh xa. Bỏ các xe gán thừa ở một số ảnh tương tự 503/561/562/563. Số phương tiện biên soạn hiện là 283, không còn 289.

## Kiểm chứng và giới hạn

`node --test tests/animation-review.test.mjs`: 10/10 pass. Có kiểm tra nghịch đảo phép chiếu, hướng dọc thân song song trục làn trong hệ pixel, hash/mesh/copyright các GLB và giữ điểm đến khi bám nét nguồn. Kiểm tra phát hiện việc trace từng làm xe dừng sớm trước đích; đã sửa và giữ nguyên assertion.

Trình duyệt local đã mở 115 câu / 108 lượt 3D / 283 sprite 2D / 860 lần seek, không có lỗi JavaScript hoặc tải scene. Sau đó điều chỉnh lại bộ trace và điểm cuối; bản hosting được kiểm tra riêng sau deploy. Ảnh kiểm tra tại `output/playwright/animation-v3`, gồm trước/sau góc xe câu 486 và các contact sheet đối chiếu đường.

Vercel `dpl_8KL6y6Fqn2ZSjSFvKdy7aENZhY92`: alias thật đã chạy lại 115 câu / 108 lượt 3D / 283 sprite / 860 lần seek, `errors: []`, `failures: []`. Chuyển câu/Back giữ chế độ; màn hình 390×844 không tràn ngang; 0 câu được agent duyệt. Sau kiểm tra này, demo Q490 độc lập cũng được thay xe tải bằng cùng GLB, không đổi mã/data của trang review.

Deployment cuối `dpl_3EvEZK2Bd5d9mFVi87YVtsQtpXiz` READY: demo 490 tải và seek xe tải GLB thành công; review 486 ở 3D tải được, ảnh chụp `production-486-corrected.png`. Tab mới chặn toàn bộ GLB vẫn xem được 2D với 5 sprite, không gửi request GLB; reload bản 3D ở 390×844 không tràn ngang.

Trong kiểm tra hình ảnh demo 490 sau khi thay GLB, phát hiện matcher bánh chưa tính tới GLTFLoader đổi dấu cách trong tên thành underscore. Wheelbase của xe tải bị 0, khiến hàm lấy hướng theo hai trục trả góc 0. Đã sửa matcher và thêm regression kiểm tra tên node đã sanitize trong cả 8 asset đường bộ. Deployment thay thế `dpl_9iNMXC9fydQKpZ1T5wca7GfxfcAB`: kiểm tra live xe tải có 6 cụm bánh, wheelbase 4.41 m; yaw ở 0%/45%/75% lần lượt 3.100/-1.948/-1.601 rad, không còn cố định 0. Cả 8 loại đường bộ đều có từ 2 cụm bánh và wheelbase dương; đầu máy tĩnh không dùng wheelbase để chạy trong bộ câu này. Ảnh trước/trong/sau cua: `production-legacy-heading-*.png`.

Đã chạy lại toàn bộ kiểm tra browser trên deployment thay thế sau sửa matcher: 115 câu, 108 lượt 3D, 283 sprite, 860 lần seek; `errors: []`, `failures: []`, giữ chế độ khi điều hướng, không tràn ngang ở 390 px. Bộ Node giữ 10/10 pass.

Bộ dò nhận 84/105 đường khảo sát, cộng mốc thủ công được giữ cho câu 486; đây là kiểm tra hình học, không phải xác nhận pháp lý hay bảo đảm mọi đường đã được người dùng duyệt. Các đường bị ảnh xe/biển che, nét đứt hoặc không có mũi tên đỏ vẫn có thể cần căn tiếp bằng mắt. Khớp rơ-moóc vẫn chưa mô phỏng riêng; ảnh gốc còn mờ dưới mesh. Không tuyên bố cả 115 câu đã khớp ảnh tuyệt đối.

Git: local trên `codex/prn-c2-integration-local`, không commit/push hoặc sửa schema/SQL bank. Giữ các chỉnh sửa C2 khác.
