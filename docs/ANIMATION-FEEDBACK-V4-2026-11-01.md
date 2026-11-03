# Sửa JSON 18:37 và đồng bộ toàn bộ xe POV

> Người dùng đã xuất bản duyệt cuối đủ 115/115, khớp mọi revision. Xem [biên bản chốt bản local](ANIMATION-ACCEPTED-2026-11-01.md). Các số 63/52 dưới đây ghi lại trạng thái trước lượt duyệt cuối.

Nguồn review: `E:/FPTU/2026FALL/PRN232/duyet-sa-hinh-486-600-2026-11-01.json`, xuất `2026-11-01T11:37:47.528Z`, SHA-256 `45e5290abd25e479785ffb00662f350d68fbe0c0f536bf6b38b571f668475981`. Có 102 Đã duyệt / 13 Cần sửa, revision đều khớp bản trước sửa. Giữ nguyên file người dùng.

Trước lượt này, chỉ 544 bật model xe POV xanh thật. Các POV 3D khác dùng nắp ca-pô đơn giản; 11 câu vẫn dùng ảnh khoang lái. Nay **cả 42 cảnh POV dùng cùng `blue-hatchback-v1`**, cùng GLB xe xanh, vị trí camera, vô lăng và cách cắt phần mui để nhìn thấy ca-pô. Không còn cờ bật riêng cho 544. 11 câu 555/556/557/558/559/564/570/571/577/578/590 được dựng thành thế giới 3D; hành vi dừng/quan sát đã duyệt được giữ, riêng 590 chạy theo đường cong phía trước.

**13 câu sửa theo ghi chú + 39 câu đã duyệt có đổi hình POV = 52 câu chờ xác nhận.** 63 câu còn lại giữ nguyên cả kịch bản/revision/nền; file renderer cũ được khóa SHA. Không tự giữ dấu Đã duyệt trên hình mới, không bấm duyệt thay người dùng. Trang mới khởi tạo **63 Đã duyệt / 0 Cần sửa / 52 Chưa duyệt**, giữ nguyên ghi chú/dấu; review mới hơn lưu trong trình duyệt được ưu tiên.

## Các nhận xét mới

| Câu | Sửa |
| --- | --- |
| 504 | Thu hẹp cung vòng xuyến của xe tải; giữ thứ tự mô tô → tải → khách → con và nhánh ra phía trên. |
| 523 | Khôi phục cả hướng 1 và 5 thành hai ví dụ độc lập, thay yêu cầu chỉ hướng 5 ở lượt trước. |
| 531 | Bỏ toàn bộ nét đỏ thêm bằng renderer; giữ đúng đường đỏ của ảnh nguồn. |
| 534 | Theo nét từ đầu/trục trước của xe để thân xe dài nằm phía sau nét trên cua; đo lại kích thước xe tải và quỹ đạo, giữ khách/tải trước xe con. |
| 538 | Mô tô đứng yên, không còn lượt tiến chậm. |
| 544 | Ngã ba với nhánh bên trái; đóng nhánh phải từng bị thêm vào. Dùng đúng mặt biển từ ảnh đề. |
| 551 | Đo lại đúng mặt biển giao nhau trong ảnh nguồn, thay crop từng lấy nhầm vùng cạnh xe tải. |
| 560 | Theo ghi chú mới: xe khách và mô tô giữ đứng yên; không đổi đáp án PDF. |
| 561 | Xóa hai mô tô gốc còn sót trong chính ảnh nền, giữ model 3D riêng. |
| 562 | Đặt mô tô vào làn giữa ở nhánh xa, giữ dừng theo tình huống. |
| 569 | Đảo có đầu thuôn, bó vỉa nổi, phần giữa và cột đèn nằm trên đảo; bỏ khối chữ nhật lệch hẳn sang nhánh phải. |
| 597 | Sau đoạn nhập, đi thẳng cùng trục làn chính; bỏ chuỗi điểm gây đổi sang làn nữa. |
| 599 | Đường xe đỏ là một đoạn thẳng theo trục làn; tốc độ thấp hơn xe đang vượt để không đuổi vào xe vàng. |

## Kiểm tra

- 46/46 test Node: giữ 63 bản duyệt còn nguyên; kiểm tra scope 13 + 42, một cockpit cho 42 POV, giữ ghi chú/dấu, di chuyển/tua xác định, hướng 1/5, dừng mô tô, hình học GLB/đèn/dây kéo/tay bám rào. Hợp đồng review cũ được kiểm tra trên snapshot trước lượt nâng cấp POV, không ép những yêu cầu mới về trạng thái cũ.
- Kiểm tra footprint GLB thực, 42 POV + 38 overview, 41 mẫu mỗi bước: không phát hiện giao thân xe tại các mẫu. Overview bỏ xe đã hoàn toàn ngoài viewport; tiếp xúc người gác/rào là chủ ý. Không bảo đảm mọi thời điểm liên tục.
- Desktop 1440×1100 và mobile 390×844: đủ 52 bản mới, metadata đúng revision. Đo camera/cockpit thực trên trình duyệt; phát thật 31 POV có lượt xe của bạn chuyển động. Các POV chỉ dừng/quan sát giữ camera đứng yên.
- Xem sheet tổng quan đủ 52 câu và sheet chi tiết; phát liên tục 13 cảnh 504/523/534/538/544/551/560/561/562/569/590/597/599 tới cuối ở 2×. Không đo FPS, không xem mọi khung của toàn bộ 115 câu.
- Bố trí nhãn được sửa để gọi nhiều lần vẫn cho cùng kết quả: V3 từng bố trí nhãn xe rồi bố trí lại nhãn đường, làm mất vị trí né nhau trên mobile. V4 đặt lại các mốc nhãn trước khi tính lại.

Số mốc thực tế, revision, ghi chú, loại đổi POV và event mạng được ghi ở `output/animation-review/feedback-repair-ledger-2026-11-01-v4.json` / `.md`. Các request Chromium báo hủy, nếu có, được giữ riêng; không coi chúng là lượt mạng hoàn toàn sạch. Kiểm tra local không phải nghiệm thu người dùng hoặc xác minh độc lập pháp luật/đáp án.

Ảnh gốc luôn giữ để đối chiếu. Bối cảnh 3D dựng lại dùng nhà/cây/vật liệu đơn giản, không sao chép chính xác phối cảnh và công trình của ảnh đề.

## Ảnh nền 561

Built-in ImageGen, skill: `C:/Users/LEGION/.codex/skills/.system/imagegen/SKILL.md`. Target là `content-animations/clean-plates/q561-v1.webp`; đã mở ảnh và xác nhận hai xe còn sót trước khi sửa. File mới: `content-animations/clean-plates/q561-v4.webp`. Chỉ xuất/đổi kích thước ảnh do ImageGen trả về bằng Pillow; không dùng Pillow để inpaint. Manifest và scene dùng URL/SHA mới. Ảnh đề gốc không bị ghi đè.

Prompt dùng:

> Edit target: the supplied Vietnamese driving-test junction background image. Remove ONLY the two tiny red motorcycles and their riders on the far upper-right approach, immediately below the far overhead traffic-light bar. Fill their tiny occupied areas with the same grey road surface and correct existing lane markings. Preserve the identical full composition, crop, perspective, road, sidewalks, grass, white lane arrows, pedestrian crossings, red route arrows and ALL traffic lights and their colored lamps. Do not add any vehicles or people. This must be an empty-vehicle background plate with no motorcycles anywhere. Keep the exact same aspect ratio; do not redesign, recolor, zoom, crop, or change road geometry.

Chỉ compositing plate trong mask xe đã đo; vùng ngoài mask vẫn lấy nguyên từ ảnh nguồn.

## Chạy lại

```powershell
python scripts/serve-animation-review.py
# http://localhost:8765/review.html?review=v4-20261101#q=504
python scripts/author-animation-scenes.py
node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs tests/animation-layout.test.mjs tests/animation-feedback-v2.test.mjs tests/animation-feedback-v3.test.mjs tests/animation-feedback-v4.test.mjs
node scripts/check-animation-traffic.mjs
python scripts/report-animation-feedback-v4.py
```

Nguồn: `scripts/animation_feedback_repairs_v4.py`, `review-player-v4.js`, `review-pov-v4.js`. Input/baseline/khóa SHA có hậu tố v4 trong `content-animations/bank-review`. Git vẫn `codex/prn-c2-integration-local`, HEAD `dbdcb5f`; chưa commit/push/PR/merge/deploy, giữ các thay đổi C2 sẵn có.
