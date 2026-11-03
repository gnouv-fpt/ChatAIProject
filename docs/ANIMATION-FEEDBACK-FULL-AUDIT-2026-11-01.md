# Mũ fullface và sửa theo JSON feedback — 01/11/2026

> Báo cáo lịch sử của lượt sửa theo JSON ngày 31/10. Lượt mới theo JSON ngày 01/11, giữ 44 câu đã duyệt và sửa 71 câu, được ghi riêng tại [ANIMATION-FEEDBACK-V2-2026-11-01.md](ANIMATION-FEEDBACK-V2-2026-11-01.md). Các số liệu/revision dưới đây thuộc lượt cũ.

Đã đổi mũ người lái mô tô thành fullface, có kính tối và bảo vệ cằm. Đã đối chiếu toàn bộ **115 bản ghi** của JSON ngày 31/10: **103 cần sửa, 12 đã duyệt từ trước**. Bản sửa local hiện có **115 cảnh 3D, 469 bước**, renderer revision `8fb7d5f3043efcde`; các cảnh vẫn là draft.

Đây là lượt sửa và rà nội bộ theo ảnh mẫu, **không phải nghiệm thu thay người dùng hoặc xác nhận mọi khung hình của 115 animation**. Trang kiểm tra vẫn `0 Đã duyệt / 0 Cần sửa / 115 Chưa duyệt`.

## Những thay đổi đã kiểm tra

- Mũ mới được dựng trong `scripts/build-review-humans.py`, xuất lại `traffic-motorcyclist.glb`, manifest SHA và file Blender chỉnh sửa được. Đã mở xem ảnh Blender và trang WebGL có đủ ba model; không chỉ kiểm tra tên node. Mũ gồm vỏ kín, `FullFaceVisor` và `HelmetChinVent`.
- Đường xe dùng các đoạn thẳng và phần bo tại góc rẽ. Kéo dài lối ra theo kích thước xe, kiểm tra cả hộp hình học chiếu lên ảnh; tránh đuôi xe còn chắn giao lộ khi chuyển lượt. Câu 600 đã ra hết cả rơ-moóc trước lượt xe sau.
- Căn bánh/chân theo đáy vùng xe nguồn; ô khoanh xe lấy từ hình học đang hiển thị. Các xe tiến gần ở góc khoang lái tăng tỷ lệ và đi qua bên trái, không chạy xuyên táp-lô. Mask giữ phần khoang lái ở phía trước model.
- Bố trí nhãn bằng kích thước chữ thật, tránh nhãn khác, vùng biển/đèn và mép ảnh. Câu 596/600 trên mobile không còn cặp nhãn chồng nhau ở các mốc kiểm tra.
- Đo lại bốn vùng xe ở 531, hướng xe 557/558/559/579, xe xa 587 và mô tô 592. Biển ở 592 nằm trước model. Câu 559 có xi nhan bên trái theo ảnh nguồn.
- Thu mask mặt biển/cột ở 558 để không phục hồi mái xe gốc. Câu 528 có vùng giữ người điều khiển riêng; sau khi xe tải đi, xe tải gốc không hiện lại. Câu 549 khoanh đúng mặt biển nhường đường. Câu 574 và 591 có bước đối chiếu biển/đèn trước khi phát lượt xe.
- Câu 573: người đi bộ sang tới lề trước lượt ô tô; đã xem riêng các mốc 7/9/12 giây. Câu 581: xe tải có xi nhan và chuyển làn trên mặt đường; sửa điểm kết thúc từng đưa xe lên vùng trời. Câu 594 phân biệt hai nhánh và đi theo hướng 1 tới góc xa rồi rẽ trái.
- Câu 511/512 giải thích rõ hướng bị cấm, giữ xe đứng yên. Nhóm các hướng thay thế được giải thích là các ví dụ độc lập; khung đáp án giữ pose cuối, tránh xe bật lại đầu sau ví dụ cuối.

Các sửa trước trong source cũng được đối chiếu lại theo ghi chú: dây nối 510/515/518; vượt xe và giữ biển 513; thứ tự 517/525; nhóm xe được đi dưới tín hiệu 500/503/538/553/560–565; xe C ở 566; cửa sau 576; ba người đi xe đạp 577; đèn pha 595; rào trượt/người gác 596; nhập làn/vượt xe 597–599; ba mô tô và khớp kéo 600. Không phát xe đi trên đường bị cấm chỉ để tạo chuyển động.

## Bằng chứng và phạm vi

| Kiểm tra | Kết quả và giới hạn |
| --- | --- |
| JSON gốc | Bản sao giống từng byte với file người dùng ở `E:/FPTU/2026FALL/PRN232/duyet-sa-hinh-486-600-2026-10-31.json`. SHA-256 `70b83bc6c2283a2935f47c6334bf1b692c203c2e85b49a38069fb179deaf887c`; giữ nguyên ghi chú và bốn dấu của câu 487. |
| 12 kịch bản đã duyệt | Test giữ nguyên actors, steps, note, roadCalibration, learningMode, perspective và cleanBackground so với bản trước feedback. Renderer chung đổi nên không tự chuyển chúng thành đã duyệt ở revision mới. |
| Desktop 1440×1100 | Chụp 699 mốc: đầu, giữa từng bước, cuối; thêm ảnh gốc của đủ 115 câu. Đã mở xem 20 sheet tổng quan bao phủ 115 câu, cùng ảnh lớn/sheet từng bước của các lỗi cần rà sâu. Không xem liên tục mọi khung của toàn bộ bộ câu. |
| Mobile 390×844 | 115 câu, 699 mốc: không có cặp nhãn giao nhau, nhãn tràn khỏi ảnh hoặc trang tràn ngang theo đo DOM. Đây là kiểm tra bố cục tự động; các ảnh mobile mục tiêu được xem riêng. |
| Tải/chạy WebGL | Hai lượt desktop/mobile đều `errors: []`, `failedRequests: []`; bỏ riêng favicon 404 của máy chủ local. Không phát hiện sai revision giữa bằng chứng cuối và scenes hiện hành. |
| Phát thật | Phát/dừng mẫu tại 12 câu; phát liên tục đến hết 490 và 600 ở 2×, có ảnh lấy trong khi đang phát. Chứng minh các luồng này chạy tới cuối; không phải đo FPS hoặc chứng minh độ mượt mọi animation. |
| Node | **28/28 pass**, gồm dữ liệu/SHA, giữ bản duyệt, tính xác định khi tua, thứ tự/chờ, hình học GLB, chân/bàn đạp, mask không hiện lại xe gốc, đường hướng 1 câu 594 và xe 581 ở dưới đường chân trời. Test GLB dùng texture 1 pixel trong Node; kiểm tra WebGL được làm riêng trên trình duyệt. |

Ledger từng câu giữ nguyên ghi chú gốc và gắn quan sát vào đúng revision:

- `output/animation-review/feedback-repair-ledger.md` và `.json`.
- `output/animation-review/feedback-visual-review-2026-11-01.json`: các mốc/ảnh đã xem, summary theo câu; `accepted=false`, `visualVerified=false`. `agentReviewed` trong ledger chỉ là rà nội bộ có mẫu ảnh.
- `output/animation-review/full-audit-before.json`, `full-audit-after.json`: capture và kiểm tra desktop. Bốn câu sửa cuối có file `after-corrections.json`, riêng 581 có `after-581-final.json`; bản tổng đã ghép đúng revision. `full-audit-after-first-pass.json` giữ lượt trước khi sửa các lỗi phát hiện khi xem ảnh.
- `output/animation-review/mobile-playback-audit.json`, `mobile-corrections.json`, `mobile-581-final.json`, `continuous-playback-audit.json`: kết quả mobile/phát thật.
- `output/playwright/feedback-full/before/`, `after/`, `targeted/`: ảnh thật trên trình duyệt; `after/overview-*.jpg` và `question-*.jpg` để đối chiếu. Ảnh mũ: `output/playwright/animation-review/human-motorcyclist-2026-11-01.png`; preview WebGL: `human-fullface-browser-2026-11-01.png`.

`visual-observations.json` và các báo cáo spot-check cũ được giữ để lưu lịch sử. Quan sát cũ không được coi là bằng chứng của revision mới.

## Tái tạo và trạng thái local

```powershell
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/update-feedback-cleanplates.py
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/report-animation-feedback.py
node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs tests/animation-layout.test.mjs
```

Source sửa nằm trong `scripts/animation_feedback_repairs.py`, `update-feedback-cleanplates.py`, renderer/layout và builder model. Không sửa tay dữ liệu cảnh rồi bỏ nguồn tái tạo. Ảnh đề gốc không bị sửa; những nền imagegen có từ trước vẫn là nền tái tạo, không được coi là ảnh gốc phục hồi.

Mở `http://localhost:8765/review.html#q=549` hoặc `http://localhost:8765/humans.html`. Khi xem bản mới, dùng Ctrl+Shift+R để tránh CSS/GLB cũ trong cache; các lượt kiểm tra cuối đã tắt cache bằng CDP. Đổi hash trong tài liệu đã mở không tự tải lại toàn bộ dataset.

Camera khoang lái vẫn cố định; lượt xe của bạn là đường/chấm chỉ dẫn trên ảnh, không phải camera chạy trong một thế giới 3D đầy đủ. Tỷ lệ/góc model và bề mặt đường là minh họa; chưa có animation nghiêng người riêng cho mọi cua hoặc chống chân khi dừng.

Nhánh `codex/prn-c2-integration-local`, HEAD `dbdcb5f`. Không commit, push, PR, merge hoặc deploy. Giữ nguyên các thay đổi C2 có sẵn và ZIP người dùng tải.
