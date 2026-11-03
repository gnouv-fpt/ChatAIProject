# Sửa 45 câu theo JSON xuất 17:27 ngày 01/11

> Lượt lịch sử. Review mới xuất 18:37 có 102 đã duyệt / 13 cần sửa và yêu cầu đồng bộ toàn bộ xe POV; xem [báo cáo lượt 4](ANIMATION-FEEDBACK-V4-2026-11-01.md).

Nguồn: `E:/FPTU/2026FALL/PRN232/duyet-sa-hinh-486-600-2026-11-01.json`, SHA-256 `73ac4ea4774e77e52a9e4e7c12f0aaa66567b47af065446c14b86661ca8eb7a1`. File người dùng và ảnh đề gốc không bị sửa.

**Giữ nguyên 70 câu đã duyệt**, gồm toàn bộ kịch bản/revision/nền và các file renderer phiên bản 1/2. Chỉ 45 câu Cần sửa dùng renderer phiên bản 3 và revision mới. Trang duyệt khởi tạo thành **70 Đã duyệt / 0 Cần sửa / 45 Chưa duyệt**, giữ nguyên ghi chú và dấu cũ. Dữ liệu duyệt mới hơn trong trình duyệt được ưu tiên. Không bấm duyệt thay người dùng.

## Các nhóm sửa

- Vị trí/hướng thân xe: đo lại điểm tiếp xúc mặt đường; bỏ việc mang theo offset tâm hộp ảnh khi xe chạy khiến thân xe lệch làn. Chỉnh riêng 488/489/508/516/518/520/524/528/530/534/539/540, nhóm giao lộ đèn và 599. 531 giữ bố trí model cũ, chỉ bám lại hai nét đỏ nguồn. 504 thu nhỏ theo chiều sâu khi xe tải đi tới nhánh xa.
- Quỹ đạo và thứ tự: 489 công an rẽ trái, thứ tự công an → tải → khách → con. 504 tải ra cùng nhánh phía trên với xe con, giữ thứ tự mô tô → tải → khách → con. 534 giữ khách/tải trước xe con; sửa bán kính rẽ để không phải đổi ưu tiên nhằm né va chạm. 523 chỉ phát riêng hướng 5 theo ghi chú; giữ nguyên đáp án PDF hiển thị (hướng 1 và 5).
- Giao lộ đèn 500/503/538/553/560/561/562/565: đặt lại tâm làn/xe xa, chỉnh độ rộng đường rẽ. 538 các lượt được phép có thể chạy cùng bước, có độ trễ giữ khoảng cách; khách/mô tô chỉ tiến tới vạch dừng. 553 khoanh đỏ khách/mô tô, giữ đứng yên và không tự vẽ mũi tên trên ảnh không có nét nguồn. 560 chỉ minh họa xe/hướng không vi phạm theo đáp án nguồn. 500/562 bổ sung vùng xóa xe gốc, thu vùng giữ bảng đèn/cột cho 500 để không phục hồi xe phía dưới.
- POV: 544 thêm model xe của bạn, nhìn thấy nắp ca-pô thật. 545 có nét đỏ và số 1–4; 547 rẽ trái; 551 đi thẳng. 550 có A/B và quay đầu sau vạch người đi bộ. 569 có tiểu đảo. 594 có hai hướng 1/2 trên mặt đường. 573 xe xanh cũng chờ người đi bộ rồi mới rẽ; xe của bạn đi sau xe xanh. 580 tiếp tục chạy khi xe vượt đã qua; 581 tiếp tục chạy chậm khi tải chuyển làn.
- Biển 549/550/575/582/584/585/586/587/588 dùng mặt biển từ ảnh đề, giữ đúng màu/ký hiệu thay cho glyph chung. 584/585 thêm cả biển phụ. 586/587 đặt biển tránh cây che mặt.
- 597 thêm lượt nhập làn đúng hướng sau khi xe làn chính đã qua. 598 xe xanh vượt nhanh hơn và giữ làn vượt đến khi thoát xe tải. 600 chỉ container chuyển động; các xe khác đứng yên, chỉnh mô tô ở nhánh trên theo trục làn nguồn.

## Bằng chứng

- 41/41 test Node: bảo toàn 70 bản duyệt và SHA renderer cũ; giữ ghi chú/dấu; thứ tự/hướng xe mới; biển/tiểu đảo/đường hướng; camera và chuyển động; GLB/đèn/dây kéo/tay bám rào; không giao footprint tại 41 mốc mỗi bước. Log: `tmp/animation-v3-tests.log`.
- Desktop 1440×1100 và mobile 390×844: đủ 45 câu sửa, đầu/giữa từng bước/cuối, metadata khớp revision hiện hành. 8 sheet tổng quan đã mở xem đủ 45 câu; các chi tiết được sửa sau đó có chụp lại riêng. Mobile đo DOM không có nhãn giao/tràn hoặc tràn ngang ở các mốc. Không ghi nhận lỗi JavaScript/HTTP lỗi trong hai lượt lấy mẫu này.
- Phát liên tục 2× tới cuối ở 489/504/534/538/550/551/573/580/597/600; lưu ảnh khi đang phát. Kiểm tra chuyển qua lại renderer 1/2/3, Next rồi Back. Các lần script chờ nhầm chế độ Ảnh gốc hoặc grid mobile đóng đã được chỉnh điều kiện và chạy lại; không tính lần timeout là pass.
- 31 POV + 38 overview được kiểm tra footprint từ GLB thực, tính cả scale chiều sâu của renderer, tại 41 mẫu mỗi bước. Bỏ xe đã hoàn toàn ngoài viewport; tiếp xúc tay người gác/rào là chủ ý. Đây là lấy mẫu, không chứng minh mọi thời điểm liên tục không va chạm.

Số mốc, revision, ghi chú và bằng chứng từng câu nằm trong `output/animation-review/feedback-repair-ledger-2026-11-01-v3.json` và `.md`. Nếu có sự kiện Chromium hủy request GLB thì giữ riêng trong ledger; không đổi chúng thành tuyên bố mạng hoàn toàn sạch.

Bối cảnh POV vẫn là 3D dựng lại với nhà/cây/vật liệu đơn giản, khác phong cách ảnh đề; chọn Ảnh gốc để đối chiếu. Lượt này không xác minh pháp luật/đáp án độc lập, không đo FPS và không nghiệm thu thay người dùng.

## Chạy lại

```powershell
python scripts/serve-animation-review.py
# http://localhost:8765/review.html#q=544
python scripts/author-animation-scenes.py
node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs tests/animation-layout.test.mjs tests/animation-feedback-v2.test.mjs tests/animation-feedback-v3.test.mjs
node scripts/check-animation-traffic.mjs
python scripts/report-animation-feedback-v3.py
```

Nguồn sửa: `scripts/animation_feedback_repairs_v3.py`, gọi sau lượt v2. Input mới lưu riêng ở `review-feedback-v3-input.json`, snapshot tại `review-baseline-v3.json`, khóa renderer tại `review-approved-lock-v3.json`, cùng thư mục `content-animations/bank-review`. Input v2 đã tách thành `review-feedback-v2-input.json` để kết quả lịch sử không bị thay theo lần tải JSON mới.

Git: `codex/prn-c2-integration-local`, HEAD `dbdcb5f`. Chưa commit/push/PR/merge/deploy. Không reset/dọn các thay đổi C2 và animation đã có.
