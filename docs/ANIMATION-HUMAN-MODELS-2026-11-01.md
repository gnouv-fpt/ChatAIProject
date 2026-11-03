# Model người cho đi bộ, xe đạp và mô tô — 01/11/2026

Cập nhật tiếp theo trong ngày: mũ mô tô đã đổi thành **fullface**, có kính tối và bảo vệ cằm. Các lỗi sa hình/nhãn/phối cảnh nêu ở cuối bản ghi ban đầu bên dưới đã được rà tiếp trong [báo cáo sửa feedback](ANIMATION-FEEDBACK-FULL-AUDIT-2026-11-01.md). Số bước, revision và kiểm tra hiện hành nằm ở báo cáo đó; phần dưới lưu bằng chứng của lượt thay model trước khi sửa feedback.

Đã thay Hoodie trong renderer local bằng **Man của Quaternius**, nguồn [Poly Pizza](https://poly.pizza/m/HMnuH5geEG), trang nguồn ghi Public Domain (CC0). Nhân vật có áo, quần ngắn, giày và khuôn mặt. Không dùng nhân vật để trần trong ZIP người dùng đã tải.

## Ba trường hợp

| Trường hợp | Tài sản | Chuyển động |
| --- | --- | --- |
| Đi bộ | `models/people/traffic-pedestrian.glb` | Walk/Idle từ model gốc; bước theo quãng đường actor, đứng chờ ngoài bước move. Giữ translation của khớp chân vì rig này có Foot là target riêng. |
| Xe đạp | `models/people/traffic-cyclist.glb` | Clip Pedal được dựng/bake riêng bằng Blender, tay theo ghi đông, chân theo vị trí bàn đạp. Crank/bàn đạp thật của xe được rig và quay cùng pha; không dùng Idle giả tư thế đạp xe. |
| Mô tô/xe ba bánh | `models/people/traffic-motorcyclist.glb` | Tư thế Ride dựng riêng theo yên, ghi đông/gác chân của model mô tô; thêm mũ bảo hiểm gắn theo đầu. |

Hai clip Pedal/Ride và mũ là phần biên soạn local, **không phải animation có sẵn của model tải về**. Người đi xe đạp được chỉnh tỷ lệ chân trong biến thể riêng để phù hợp yên xe đang dùng. Xe chờ không tự đạp tại chỗ; pha chân và crank được tính từ quãng đường để tua lùi có kết quả xác định.

Trang xem thử: `http://localhost:8765/humans.html`. Có phát/dừng, về đầu và góc nghiêng/bên hông/phía trước; có link đến 573/577/486. File: `content-animations/humans.html`, `humans.css`, `humans.js`.

## Blender và nguồn tái tạo

MCP Blender trả “Could not connect to Blender”; đã dùng **Blender 5.1.2 chạy nền** có sẵn trên máy. Không thay scene Blender đang mở hoặc cài phần mềm mới.

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' -b --python-exit-code 1 --python scripts/build-review-humans.py
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/report-animation-feedback.py
```

Script dựng mới: `scripts/build-review-humans.py`. Nó kiểm tra hash nguồn, chuẩn hóa hướng/kích thước, dựng tay/chân bằng solver hai đoạn, bake clip, kiểm tra khả năng chạm target, xuất GLB và render ảnh. Sai số target ở keyframe được ghi trong `models/people/build-report.json`; script dừng nếu target xa quá 2 mm. Số này chỉ đánh giá khớp, không phải bằng chứng bề mặt da/ngón tay hoàn hảo.

- Model nguồn nguyên vẹn: `content-animations/models/people/man-casual-source.glb`.
- URL nguồn/tải, CC0, SHA-256 và kích thước từng GLB: `content-animations/models/people/manifest.json`.
- Hướng dẫn nguồn và cách dựng: `content-animations/models/people/SOURCES.md`.
- File Blender chỉnh sửa được: `output/animation-review/traffic-cyclist.blend`, `traffic-motorcyclist.blend`.
- Hoodie cũ giữ nguyên để truy nguồn. Mẫu Casual Character thử nhưng không chọn nằm riêng trong `output/animation-review/human-candidates/`.

## Kiểm chứng đã thực hiện

- Đã render và mở xem ba profile bằng Blender, rồi xem trên WebGL với góc nghiêng/bên hông/phía trước; đã xem cả preview mobile 390×844.
- Playwright mở **44 cảnh có pedestrian/bicycle/moto/tricycle**, tua giây 0 và 7; `errors: []`, `failedRequests: []` (bỏ favicon nếu thiếu). Đây là kiểm tra tải/chạy, không phải thẩm định hình ảnh 44 câu.
- Đã mở xem ảnh các cảnh 486, 573, 577. Có ảnh bổ sung 510, 587, 596 để tiếp tục đối chiếu. Câu 577 hiển thị ba rig xe đạp riêng; kịch bản câu này vẫn giữ đoàn xe ở tư thế minh họa theo cue, trang preview thể hiện vòng đạp liên tục.
- Preview và các cảnh 486/573/577 ở 390×844 không tràn ngang.
- `node --test tests/animation-review.test.mjs tests/animation-feedback.test.mjs tests/animation-fleet-geometry.test.mjs`: **23/23 pass**. Kiểm tra hình học bổ sung 41 mốc trong một vòng đạp: khớp cổ chân theo target đặt trên hai bàn đạp thật trong 3 mm, tua lùi cho cùng pose, các cyclist không chia sẻ skeleton, người chờ dùng Idle, mô tô giữ rig bàn tay và mũ.
- Các test Node dùng texture 1 pixel để giải mã GLB, không thay kiểm tra texture/WebGL; phần WebGL đã xem riêng. `node --check` qua các module đã đổi.
- Manifest khớp SHA mọi file người; `rendererRevision` hiện hành `86ae9aba1f9108b3` khớp renderer/GLB. Scenes vẫn **115 cảnh 3D, 466 bước**, trạng thái draft. UI **0 Đã duyệt / 0 Cần sửa / 115 Chưa duyệt**.

Ảnh: `output/playwright/animation-review/human-*.png`. Script kiểm tra trình duyệt: `output/playwright/check-human-models-2026-11-01.cjs`. Ảnh trang xem thử dùng trong bàn giao: `human-preview-browser-2026-11-01.png`.

## Giới hạn

Model có phong cách low poly; bàn tay/ngón tay và tư thế ngồi là minh họa, chưa phải animation người thật. Tư thế lái hiện theo ghi đông, không có bộ nghiêng người/đánh lái riêng cho mọi cua hoặc tư thế chống chân xuống đường khi dừng.

Camera/đường chạy sa hình không được biên soạn lại trong task model này. Ở câu 573, khung giây 7 vẫn cho người đi bộ đi gần/chồng vùng vô-lăng trên ảnh nền cố định; cần rà đường đi/phối cảnh tiếp. Các giới hạn 580, nhãn mobile 596/600 và đuôi rơ-moóc 600 từ đợt rà trước vẫn chưa được giải quyết bởi việc đổi model. Không coi trang preview là bằng chứng đã nghiệm thu vị trí người trong đủ 115 câu.

Renderer chung đổi revision nên quan sát của đợt 13 cảnh trước thuộc revision cũ. `visual-observations.json` được giữ nguyên để lưu lịch sử; report không gắn chúng với bản mới hoặc tự duyệt lại. Không nhập/publish SQL, commit, push, PR hoặc deploy. Nhánh `codex/prn-c2-integration-local`, HEAD `dbdcb5f`; giữ các thay đổi C2 có sẵn.
