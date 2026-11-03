# Rà cảnh đặc biệt — 01/11/2026

Đã có lượt rà tiếp theo theo toàn bộ JSON và đổi mũ fullface: [báo cáo hiện hành](ANIMATION-FEEDBACK-FULL-AUDIT-2026-11-01.md). Các giới hạn 580/596/600 bên dưới là ghi nhận của bản cũ; xem kết quả sửa và phạm vi kiểm tra mới ở báo cáo hiện hành.

Sau đợt rà này, model người/renderer đã đổi: [báo cáo model người mới](ANIMATION-HUMAN-MODELS-2026-11-01.md). Các quan sát bên dưới thuộc revision trước; ledger hiện hành không coi chúng là quan sát của revision mới.

Đã rà một phần 13 cảnh: 510, 513, 515, 518, 547, 567, 573, 580, 584, 587, 596, 598, 600. Đây là kiểm tra nội bộ theo các khung hình được liệt kê, chưa phải nghiệm thu đủ 115 câu hoặc kiểm chứng độ mượt của toàn bộ video.

## Thay đổi

- **513:** thu nhỏ/dịch xe con để lộ biển; đường vượt giữ bên trái lâu hơn và chỉ trở lại làn sau khi qua xe tải. Mask giữ biển được thay từ hình chữ nhật rộng sang polygon quanh hai mặt biển/cột, tránh hiện lại một mảng xe gốc sau khi model đi khỏi chỗ.
- **573:** người đi bộ đi qua phía trước xe con đang chờ rồi tới lề trái. Trước sửa, người dừng ở `[47,67]`, ngay trên đường chỉ dẫn rẽ của xe mình.
- **587:** người đi bộ đi hẳn tới vỉa hè phải trước lượt xe mình, thay vì dừng trên mặt đường.
- Thay đổi ở `scripts/animation_feedback_repairs.py` và `scripts/update-feedback-cleanplates.py`; tạo lại `content-animations/bank-review/scenes.json`: **115 cảnh 3D, 466 bước**. Không sửa ảnh nguồn hoặc đáp án.
- `scripts/report-animation-feedback.py` đọc quan sát ở `output/animation-review/visual-observations.json` khi revision khớp. Ledger có ghi chú một phần cho 13 cảnh; `visualVerified` vẫn false và không thay trạng thái duyệt gốc. Quan sát cũ tự bị bỏ khỏi ledger hiện hành khi revision đổi.

## Bằng chứng

Mốc đã thực sự xem, revision và đường dẫn ảnh nằm trong `output/animation-review/visual-observations.json`; bảng đọc nhanh ở `output/animation-review/feedback-repair-ledger.md`. Ảnh trong `output/playwright/animation-review/2026-11-01-*.png`. Các sheet cuối của 513/573/587 và mobile được mở xem trực quan.

- Desktop 1440×1100: đối chiếu ảnh gốc với các khung đầu/giữa/cuối ở nhóm dây kéo, biển/đèn, vượt xe, người đi bộ, rào chắn và container. Dây nối 510/515/518 nhìn thấy; biển/đèn 547/567/584 nhìn rõ tại các khung đã ghi. Chưa thể suy ra mọi mốc đều đạt.
- 513 sau sửa: xem 0, 1.5, 3, 4.5, 6, 7.5, 8.99, 11.99 giây; hai biển lộ rõ, không thấy mảng xe gốc xuất hiện lại hoặc model chạm xe tải trong các khung này. Tỷ lệ/góc model vẫn gần đúng.
- 573/587: đã xem thêm lúc người tới lề, lúc xe mình bắt đầu đi và cuối cảnh; người đứng ngoài đường chỉ dẫn của xe mình.
- 600: xem 14 mốc từ 0 tới 24.99 giây; thấy rơ-moóc thay góc qua khớp và ba xe phía sau chờ tới bước sau giây 16. Đây là tua khung hình; chưa chứng minh độ mượt liên tục.
- Mobile 390×844: mở 513/573/587/596/600 và xem giây 0/12, không tràn ngang. Nhãn ở 596/600 vẫn chồng nhau, ghi dưới đây.
- Chạy phát/dừng thật ở 573, chuyển 574 rồi Back về 573 thành công. Lượt kiểm tra cuối: `errors: []`, `failedRequests: []` (bỏ riêng favicon nếu thiếu), **0 Đã duyệt / 0 Cần sửa / 115 Chưa duyệt**.

Script chụp: `output/playwright/capture-special-scenes-2026-11-01.cjs`, `capture-special-followup-2026-11-01.cjs`, `check-special-final-2026-11-01.cjs`. Chạy qua Playwright CLI `run-code --filename`. Dùng URL có query riêng để tải lại dataset sau khi sinh scenes; đổi hash trong tài liệu đang mở vẫn dùng dữ liệu đã tải trước đó.

## Kiểm tra tự động

```powershell
node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs
```

23/23 pass sau bản sửa cuối. Hai regression mới kiểm tra người đã ra khỏi hành lang xe trước lượt xe mình, và mask giữ mặt biển 513 mà không giữ lại vùng xe gốc. Các kiểm tra còn lại bao gồm SHA ảnh/asset, 12 kịch bản đã được người dùng duyệt trước feedback, hình học/chuyển động và import trạng thái theo revision. Kiểm tra Node không chứng minh chất lượng WebGL; phần đó được xem riêng trên trình duyệt.

## Còn cần làm

- **580:** xe tiến về người xem nhưng tỷ lệ không tăng theo khoảng cách, cuối đường chạy xuống vùng táp-lô. Cần sửa phối cảnh/điểm ra khỏi khung.
- **596/600 trên mobile:** tránh chồng nhãn của các actor gần nhau. Hiện chỉ xác nhận không tràn ngang, chưa đạt chất lượng nhãn.
- **600:** cuối cảnh còn một phần rơ-moóc ở mép phải. Cần xem chuyển động liên tục, khoảng cách nhóm mô tô/xe con và toàn bộ phần đuôi khi ra khung.
- Chưa rà đầy đủ mọi khung của nhóm 13 cảnh, các cảnh đặc biệt khác, mọi tỷ lệ màn hình hoặc các lỗi tải. Chưa có animation đạp xe chuyên biệt; các cảnh nhìn từ khoang lái vẫn dùng camera cố định.

## Tái tạo local và Git

```powershell
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/update-feedback-cleanplates.py
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/report-animation-feedback.py
```

Python HTTP server mặc định trên máy Windows này trả `.mjs` thành `text/plain`, làm trình duyệt chặn module. Máy chủ kiểm tra dùng cấu hình MIME rõ ràng:

```powershell
python -c "import http.server,functools; http.server.SimpleHTTPRequestHandler.extensions_map.update({'.mjs':'text/javascript','.js':'text/javascript'}); http.server.ThreadingHTTPServer(('127.0.0.1',8765),functools.partial(http.server.SimpleHTTPRequestHandler,directory='content-animations')).serve_forever()"
```

Mở `http://localhost:8765/review.html#q=513`. Nhánh `codex/prn-c2-integration-local`, HEAD `dbdcb5f`. Không commit, push, PR hoặc deploy. Giữ nguyên các thay đổi C2 có sẵn; không thao tác lên remote hoặc ZIP nhân vật gốc. Bản sửa 01/11 chỉ tồn tại local.
