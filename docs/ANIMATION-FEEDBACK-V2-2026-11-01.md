# Sửa animation theo JSON ngày 01/11 — lượt 2

> Lượt này thuộc bản review 44 đã duyệt / 71 cần sửa. Bản review mới xuất 17:27 có 70 đã duyệt / 45 cần sửa; xem [báo cáo lượt 3](ANIMATION-FEEDBACK-V3-2026-11-01.md) và ledger riêng để đối chiếu trạng thái hiện hành.

Nguồn: `E:/FPTU/2026FALL/PRN232/duyet-sa-hinh-486-600-2026-11-01.json`. File gốc được giữ nguyên. Bản sao phục vụ trang duyệt nằm tại `content-animations/bank-review/review-feedback.json`.

Giữ nguyên toàn bộ kịch bản, revision và các file renderer cũ của **44 câu người dùng đã duyệt**. **71 câu Cần sửa** có revision mới và trở thành Chưa duyệt, giữ nguyên ghi chú/dấu của người dùng. Trang local khởi tạo từ JSON là **44 Đã duyệt / 0 Cần sửa / 71 Chưa duyệt**; dữ liệu duyệt mới hơn trong trình duyệt vẫn được ưu tiên. Không bấm duyệt thay người dùng.

## Thay đổi

- 31 cảnh POV dùng camera phối cảnh gắn với xe của bạn trong thế giới 3D chung. 30 cảnh có lượt xe của bạn di chuyển; riêng 596 xe dừng suốt cảnh. Xe khác, người, biển, đèn, đường và camera cùng dùng tọa độ mét, không kéo model trên ảnh khoang lái. Có gương chiếu hậu render từ cảnh thật.
- Sửa quỹ đạo/hướng/nhánh, vị trí và góc model theo nhận xét; tách các lượt có nguy cơ va chạm. Các hướng minh họa thay thế được reset riêng, có ghi rõ trong giao diện. Ví dụ 491 đổi đúng nhánh xe tải/xe con; 516 xe khách chờ xe tải qua; 539 sửa hướng 3; 561 hai mô tô rẽ phải; 563 đặt lại xe con xa và không cho xe bị cấm chạy.
- Dây kéo 510/515/518 là mesh 3D nối các điểm trên cản xe và cập nhật theo pose. Xi nhan 559/581 gắn sát hình học thân xe, có nhấp nháy. 595 xe ở mặt đường, có đèn chiếu gần; 596 người gác kéo rào với tay bám rào, không đi qua đường ray. 598 xe đỏ chạy chậm trong làn; 599 cả ba xe chạy; 600 các xe đi sau giữ khoảng cách và đường thẳng song song.
- Giữ model người/GLB đang có, gồm mũ fullface người lái mô tô. Các file cũ phục vụ 44 câu đã duyệt được khóa SHA. Renderer v2 chỉ dùng ở 71 câu sửa; CSS mới giới hạn trong lớp v2.

**Bối cảnh POV được dựng lại với nhà/cây/vật liệu đơn giản, khác phong cách ảnh nguồn.** Nút Ảnh gốc giữ ảnh đề để đối chiếu. Không khẳng định sao chép chính xác hình ảnh hoặc đã xác minh độc lập pháp luật/đáp án toàn bộ ngân hàng.

## Kiểm tra và giới hạn

| Kiểm tra | Bằng chứng |
| --- | --- |
| Kịch bản | 115 cảnh 3D, 437 bước. Chạy lại script sinh cảnh cho kết quả giống từng byte. 44 kịch bản đã duyệt deep-equal với bản khóa, SHA renderer cũ không đổi. |
| Node | 35/35 test pass: dữ liệu, giữ bản duyệt, chuyển động/tua xác định, chân/bàn đạp, hình học, va chạm, đèn sát thân, dây kéo và tay bám rào. `tmp/animation-v2-all-tests.log`. Test hình học Node dùng texture giả 1 pixel; trình duyệt kiểm tra render riêng. |
| Desktop 1440×1100 | 71 câu sửa, 408 mốc đầu/giữa từng bước/cuối và 71 ảnh gốc. Đã mở 12 sheet tổng quan bao phủ 71 câu; xem thêm sheet chi tiết mục tiêu. Không xem mọi khung hình liên tục của toàn bộ 115 câu. |
| Mobile 390×844 | 71 câu sửa, 408 mốc; đo DOM không có nhãn đè nhau/tràn ảnh hoặc tràn ngang trang ở các mốc. Phát thật 30 cảnh POV có chuyển động, camera đổi vị trí; mở ảnh mobile mục tiêu 544/573/596/600. |
| Hình học thực | 31 POV + 38 overview, 41 mẫu mỗi bước: không phát hiện footprint xe chồng nhau. Overview bỏ xe đã hoàn toàn ra khỏi viewport; tiếp xúc tay người gác/rào là chủ ý. Đây là kiểm tra lấy mẫu, không bảo đảm mọi thời điểm liên tục. |
| Phát liên tục | 14 câu 488/489/491/504/516/520/539/544/552/573/581/595/596/600, 2× tới cuối và dừng. Ảnh được lấy khi đang phát. Không phải đo FPS hoặc đánh giá độ mượt toàn bộ bộ câu. |
| Hồi quy trang duyệt | Mở 44 câu đã duyệt bằng renderer cũ, kiểm tra trạng thái/revision; kiểm tra Next rồi Back. Không ghi trạng thái duyệt. |

Kết quả cuối gắn revision và số mốc thực tế nằm trong `output/animation-review/feedback-repair-ledger-2026-11-01-v2.json` và `.md`. Desktop/mobile 71 câu không ghi nhận lỗi JavaScript hoặc HTTP lỗi. Lượt phát liên tục và hồi quy 44 câu không ghi nhận lỗi JavaScript, nhưng Chromium ghi nhận lần lượt 3 và 8 sự kiện `net::ERR_ABORTED` của request GLB; các cảnh vẫn tải xong và lượt phát tới cuối. Đã tái hiện riêng sự kiện GLB bị báo hủy sau HTTP 200 (`v2-request-cancellation-diagnostic.json`). Chưa kết luận nguyên nhân ở trình duyệt/loader; giữ nguyên sự kiện trong ledger, không gọi đó là lượt mạng hoàn toàn sạch. Các lượt reload trước được giữ riêng trong `v2-*-navigation-reloads.json`.

## Chạy local và sinh lại

```powershell
python scripts/serve-animation-review.py
# http://localhost:8765/review.html#q=488

python scripts/author-animation-scenes.py
node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs tests/animation-layout.test.mjs tests/animation-feedback-v2.test.mjs
node scripts/check-animation-traffic.mjs
python scripts/report-animation-feedback-v2.py
```

Nguồn sửa là `scripts/animation_feedback_repairs_v2.py`, gọi sau phần sinh cảnh cũ. Input giữ bản duyệt ở `content-animations/bank-review/review-approved-2026-11-01.json` và khóa SHA ở `review-approved-lock-2026-11-01.json`; không phụ thuộc bản snapshot trong output để sinh lại 44 câu.

Máy chủ riêng bind 127.0.0.1:8765, trả JS/MJS đúng MIME và `Cache-Control: no-store`. Link chỉ dùng trên máy này. Không deploy.

Nhánh `codex/prn-c2-integration-local`, HEAD `dbdcb5f`. Chưa commit/push/PR/merge/deploy. Giữ các thay đổi C2 và animation đã có; không reset/dọn working tree.
