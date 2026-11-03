# Bản duyệt 115 câu sa hình — 31/10/2026

Cập nhật 01/11 sau đổi mũ fullface và sửa theo JSON: [báo cáo rà toàn bộ danh sách feedback](ANIMATION-FEEDBACK-FULL-AUDIT-2026-11-01.md). Những lượt rà bên dưới lưu lịch sử; không phải trạng thái nghiệm thu hiện hành.

Model người hiện hành từ 01/11: [Man — đi bộ, đạp xe và lái mô tô](ANIMATION-HUMAN-MODELS-2026-11-01.md), có trang xem thử và clip/tư thế dựng bằng Blender. Bằng chứng 31/10 dưới đây là lịch sử, không thay kiểm tra revision mới.

Rà bổ sung ngày 01/11: [13 cảnh đặc biệt, sửa 513/573/587 và các giới hạn còn lại](ANIMATION-SPOTCHECK-2026-11-01.md). Đây vẫn là kiểm tra nội bộ một phần, không phải nghiệm thu 115 câu.

Đây là bằng chứng bản đầu. Bản mở rộng 3D/2D và số lượng hiện hành ở [ANIMATION-3D-2D-2026-10-31.md](ANIMATION-3D-2D-2026-10-31.md).

Trang duyệt: https://content-animations.vercel.app/review.html#q=486

## Phạm vi

- Câu 486–600: 115 bản nháp, 441 bước; 44 câu có mô hình xe 3D chạy theo đường cấu hình riêng, 71 câu có khung/đường chỉ dẫn động trên ảnh gốc.
- Mỗi câu có ảnh JPEG nguyên bản, nội dung/phương án và ảnh nguyên câu từ PDF để đối chiếu đáp án gạch chân. Không dùng LLM để suy ra đáp án.
- Mỗi câu có trạng thái Chưa duyệt / Đã duyệt / Cần sửa, ghi chú và tối đa 20 dấu vị trí trên ảnh.
- Đây là gói tĩnh để duyệt nội dung; chưa nhập/publish vào Content SQL và chưa gán ExplanationAnimationUrl trong bank đang chạy.

## Cách duyệt

Chọn câu, phát hoặc kéo thanh thời gian; chuyển giữa Ảnh gốc, Chỉ dẫn trên ảnh và Mô hình xe khi câu có 3D. Dùng “Xem nguyên câu trong PDF” để đối chiếu. Chọn “Duyệt & câu tiếp” hoặc “Cần sửa”, nhập ghi chú và đánh dấu vị trí cần sửa.

Kết quả lưu bằng localStorage trên đúng trình duyệt/origin đang sử dụng, không đồng bộ lên máy chủ. Dùng “Tải kết quả JSON” để sao lưu/gửi lại; “Nhập bản duyệt” khôi phục file cùng bộ nguồn. Khi đường đi hoặc bộ dựng/mô hình thay đổi, revision thay đổi: kết quả cũ quay về Chưa duyệt, giữ ghi chú/dấu. Không có thao tác publish bank trong trang này.

## Nguồn và tái tạo

[Bản PDF nguồn trên kho dữ liệu Tuyên Quang](https://khodulieu.sohoa.tuyenquang.gov.vn/congthongtin/media/edb12a6ad8ecfde537ec02cbb7e2a1b1.pdf), SHA-256 `d473be679b53458a33acc52057f3a4fe532ea489e91d88fb86789073cd98a9c5`.

`scripts/build-animation-review.py <pdf>` trích ảnh gốc và vùng nguyên câu; nhận đáp án từ nét gạch chân hình học trong PDF bằng PyMuPDF. Báo cáo trích xuất có 115 câu, không có cảnh báo; mỗi câu đúng một phương án gạch chân. Không phải kết quả thẩm định pháp lý độc lập.

`python -X utf8 scripts/author-animation-scenes.py` tạo scenes.json từ các tọa độ/đường đi biên soạn thủ công. Chạy lại sau khi sửa bộ dựng, mô hình hoặc recipe để cập nhật revision. Mô hình xe và giấy phép tại [SOURCES.md](../content-animations/models/SOURCES.md); Three.js được lưu cùng gói và kèm MIT license.

Bản 31/10 dùng `content-animations/models/people/hoodie-character.glb` của Quaternius, tải từ Poly Pizza và ghi Public Domain (CC0 1.0). Cùng nhân vật được gắn vào actor người đi bộ, xe đạp và mô tô; người đi bộ phát clip Walk tại chỗ, người lái xe dùng tư thế trung tính với thân hơi nghiêng về trước. Bản này đã được thay bởi Man ngày 01/11 theo báo cáo ở đầu file. Asset nguồn và ghi chú giấy phép tại [people/SOURCES.md](../content-animations/models/people/SOURCES.md). GLB được đưa vào hash `rendererRevision` bằng cách quét đệ quy thư mục model; chạy lại script sinh scenes sau khi sửa renderer/model.

## Kiểm chứng

- `node --test tests/animation-review.test.mjs`: 5/5 pass; đủ dải số, ảnh gốc khớp hash, source proof, recipe/actor/path hợp lệ, import/export và vô hiệu hóa duyệt cũ theo revision.
- Trình duyệt local: mở đủ 115 câu, seek qua giữa cả 441 bước; không có lỗi JavaScript, ảnh thiếu hoặc tràn ngang ở kích thước desktop kiểm tra.
- Bổ sung model người: đã mở trực quan câu 573 (người đi bộ đi qua, không chồng thân xe con), 577 (ba người trong đoàn xe đạp) và 486 (người lái mô tô). Trang local báo 0 Đã duyệt / 0 Cần sửa / 115 Chưa duyệt; không thay đổi trạng thái nghiệm thu. Câu 577 cho thấy tư thế người trên xe đạp vẫn là tư thế minh họa đơn giản, chưa phải animation đạp xe chuyên biệt.
- Chụp/xem toàn bộ 115 scene trong `output/playwright/animation-review/`, kiểm tra lại các đường cua nhóm 3D với ảnh nguồn. Đây là kiểm tra bản nháp, không thay việc người dùng duyệt từng câu.
- Kiểm tra thật trên UI: giữ ghi chú/dấu/trạng thái sau reload; lọc; tải và nhập JSON; duyệt sang câu tiếp rồi Back; modal nguồn; phát/dừng; ảnh gốc; màn hình 390×844 không tràn ngang.
- Lỗi giả lập riêng: dữ liệu HTTP 503 → thử lại thành công; model bị chặn → xem chỉ dẫn ảnh → tải lại model thành công. Không gọi đây là sự cố cloud thực tế.
- Dữ liệu duyệt dùng cho kiểm tra local đã xóa riêng theo key của trang; không có câu nào được agent duyệt thay người dùng trên hosting.
- Vercel deployment `dpl_6EL5HrA3957fmkyXKcte8usxukdA` READY, alias `content-animations.vercel.app`. Trình duyệt trên alias thật đã mở đủ 115 câu và seek qua 441 bước: `failures: []`, `errors: []`, 0 đã duyệt / 115 chưa duyệt. Modal nguồn câu 600 tải được; reload ở 390×844 không tràn ngang. Ảnh kiểm chứng: `production-desktop.png`, `production-mobile-600.png` trong thư mục ảnh nêu trên.

## Giới hạn cần người dùng duyệt

Ảnh nguồn không bị sửa hoặc inpaint. Ở chế độ 3D, ảnh được làm mờ; xe gốc đứng yên vẫn xuất hiện để đối chiếu, mô hình màu là lớp chuyển động. Chế độ chỉ dẫn ảnh minh họa bằng vùng/đường, không làm xe trong ảnh tự chạy. Đường và kích thước xe là tọa độ biên soạn thủ công; góc nhìn là phép chiếu gần đúng. Xe chuyên dụng là mô hình đơn giản; container câu 600 chưa có khớp đầu kéo/rơ-moóc. Chưa được chấp thuận làm lời giải chính thức cho bank.

Git: làm local trên `codex/prn-c2-integration-local`; không commit hoặc push trong công việc này. Giữ nguyên các thay đổi C2 khác có sẵn trong working tree.
