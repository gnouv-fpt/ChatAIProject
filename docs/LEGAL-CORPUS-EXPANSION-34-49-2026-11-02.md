# Rà soát mở rộng corpus luật — Điều 34–49 · 02/11/2026

## Kết quả

Đã chuẩn bị gói bổ sung 16 điều (34–49) từ VBHN 55/VBHN-VPQH 2026. Gói nối tiếp corpus Điều 1–33 hiện có, đưa tổng phạm vi nguồn đã đối chiếu lên Điều 1–49. Chủ đề mới gồm phân loại và điều kiện phương tiện, biển số/đăng ký xe, đấu giá biển số, niên hạn và an toàn kỹ thuật xe, cùng quy định an toàn cho một số loại hình vận tải.

- Gói: [`content-bank/legal/55-2026-articles-34-49-review.json`](../content-bank/legal/55-2026-articles-34-49-review.json)
- Công cụ tạo/đối chiếu: [`scripts/prepare-reviewed-legal-extension.py`](../scripts/prepare-reviewed-legal-extension.py)
- Nội dung TVPL bổ sung cho phần capture bị khuyết: [`content-bank/legal/55-2026-articles-34-49-source-supplement.txt`](../content-bank/legal/55-2026-articles-34-49-source-supplement.txt).
- Số hash nội dung: `dac519893e78e3c31e51052d775d599c1cd7057095a40ab588dbc875b277a04d`.
- SHA-256 PDF Chính phủ: `9a20c8e616d444e3abe63c765a225d0797b7079c9a18e5fe7da0fc4f46847dac`.

Nguồn: [trang VBHN trên TVPL](https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Van-ban-hop-nhat-55-VBHN-VPQH-2026-Luat-Trat-tu-an-toan-giao-thong-duong-bo-698683.aspx) và [hồ sơ/PDF ký trên Cổng TTĐT Chính phủ](https://vanban.chinhphu.vn/?classid=0&docid=217295&pageid=27160). Văn bản hợp nhất ghi ngày 23/03/2026; phần sửa đổi theo Luật 118/2025/QH15 có hiệu lực từ 01/07/2026. Phạm vi được giới hạn ở VBHN; chưa bổ sung mức phạt từ nghị định hoặc quy định địa phương.

## Quy trình rà soát

`python -X utf8 scripts/prepare-reviewed-legal-extension.py` đọc các capture công khai TVPL đã có, bổ sung phần bị khuyết ở Điều 35–36, rồi so từng điều 34–49 với phần thân PDF ký của Chính phủ sau chuẩn hóa khoảng trắng. Kết quả: 16/16 điều khớp; script dừng nếu thiếu capture, lặp số Điều, thay đổi capture hoặc khác nội dung.

Trình trích PDF bỏ ký tự mũ `³` tại cụm dung tích `50 cm³` ở Điều 34 khoản 1 điểm g. Đã ghi ngoại lệ chính xác vào manifest, kiểm tra trực quan vùng PDF và chuẩn hóa ký hiệu này trong gói; không nới so sánh các nội dung khác. Web crawler cục bộ trước đó bị TVPL trả HTTP 403, nên gói không khai rằng crawler lấy được nguồn. Capture bổ sung đến từ trình đọc web công khai.

Điều 50 không đưa vào: capture sẵn có kết thúc khi Điều 50 mới bắt đầu, nên không đủ nội dung để so sánh toàn điều.

## Đã nhập và kích hoạt trên stack local

Đã thêm luồng `POST /api/documents/extend-reviewed-capture` cho admin, giới hạn đúng văn bản `55/VBHN-VPQH` và phạm vi Điều 34–49. Luồng này giữ ID của document và 333 chunks cũ, đưa SQL về trạng thái Pending trước khi cập nhật Qdrant, thêm chunks mới, rồi kích hoạt khi toàn bộ index hoàn tất. Nếu index lỗi, cùng gói có thể chạy lại từ trạng thái Pending. Không tạo migration; unique index trên số hiệu văn bản vẫn giữ nguyên.

| Hạng mục | Kết quả local |
| --- | --- |
| Document ID | `047c3bb3-8f5e-401f-b151-029b60d62dab` (không đổi) |
| Version / trạng thái | `2` / Verified, Active |
| Phạm vi | Điều 1–49 |
| SQL chunks | 536: 333 cũ, 203 mới |
| Qdrant points | 536, từng ID/payload/hash/nội dung/Điều/Khoản/Điểm/URL/flags khớp SQL |
| Hash edition | `8DFEA33BF8EACB83497A3276BB326197A06D9A2D6BDD99AC3824C010D6961D3E` |

Gateway local có ActivityTimeout 2 phút, ngắn hơn lượt index toàn bộ 536 chunks. Lượt đầu qua Gateway trả HTTP 504; lúc đó SQL ở Pending và Qdrant chưa hoàn tất. Lượt tiếp theo qua Content API loopback gặp provider đóng kết nối khi embed và trả HTTP 503; SQL vẫn Pending. Lượt chạy lại hoàn tất nhờ upsert Qdrant bỏ qua các payload đã khớp. Importer local gọi trực tiếp Content API qua loopback để tác vụ index dài không bị timeout của Gateway. Hai lượt lỗi không được tính là thành công.

`python -X utf8 scripts/extend-local-legal-corpus.py` chuẩn bị/đối chiếu lại gói, nhập và kiểm tra chạy lại idempotent. `python -X utf8 scripts/check-legal-corpus-extension.py` so toàn bộ SQL với Qdrant. Sau restart, cả hai lệnh chạy lại thành công và không tạo thêm chunk. Chat thật trả `Answered` với citation Điều 34 và Điều 39 tương ứng. Lượt chat trước khi mở rộng về Điều 11 vẫn đọc lại được; gửi lại cùng `requestId` trả đúng message/citation cũ.

Luồng mở rộng hiện dành riêng cho edition 34–49 đã rà soát. Mở Điều 50 trở đi hoặc văn bản xử phạt cần gói nguồn và quy trình edition tiếp theo; không được suy ra từ kết quả 49 điều này. Không thay câu hỏi/đáp án của bank thi hay 115 animation đã duyệt.

## Kiểm tra đã thực hiện

- `python -X utf8 scripts/prepare-reviewed-legal-extension.py` — thành công, chuẩn bị 16 điều và so khớp nguồn/PDF.
- `dotnet build Presentation/Presentation.csproj --no-restore -v:q` — qua, 0 warning/error.
- `dotnet test tests/Content.Tests/Content.Tests.csproj --no-restore --filter FullyQualifiedName~LegalCorpusExtensionTests` — qua; xác nhận lỗi index để SQL Pending và retry giữ ID chunks cũ.
- `python -X utf8 scripts/extend-local-legal-corpus.py` — qua sau retry, version 2 active, 536 chunks; chạy lại sau restart giữ nguyên kết quả.
- `python -X utf8 scripts/check-legal-corpus-extension.py` — qua; 536/536 SQL–Qdrant payloads khớp.
- Gateway/User/Content/Web health qua sau restart; chat thật Điều 34/39 có citation đúng, chat cũ Điều 11 đọc và gửi lại được.
