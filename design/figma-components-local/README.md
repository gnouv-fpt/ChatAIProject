# FLM Android Components

**Sau khi gom trang ngày 27/10:** review cũ `55:17` đã xóa; dùng [Design System một trang](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-558). Component sources `55:16` còn nguyên; số liệu bên dưới là lịch sử lượt tạo thư viện 21/10.

**Trạng thái: đã tạo và kiểm tra trên Figma qua local MCP Bridge ngày 21/10/2026.** Có 7 component set, 20 variant và 20 instance review thật. [Design System một trang](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-558). Receipt: `bridge-receipt.json`; ảnh thật: `../evidence/2026-10-21/seven-components-after.png`.

Builder `code.js` là phương án chuẩn bị trước, **chưa chạy**. Không chạy lại plugin này trên file đang có các component do bridge tạo, để tránh trùng. Bản bridge dùng Auto Layout, icon SVG Lucide, action frame và native text; không tuyên bố đã tạo text/boolean property bindings hoặc nested Button instance như builder dự kiến.

Gói này tạo 7 component set và 20 variant bằng Figma Plugin API chuẩn:

| Nhóm | Trạng thái |
|---|---|
| Card | Default, Pressed, Selected, Disabled |
| Navigation | Home, Roadmap, Assistant, Transcript, Settings |
| App bar | Root, Back |
| Dialog | Confirm, Error |
| Loading | Inline, Screen |
| Empty | Search, Transcript |
| Error | Network, Quota, Import |

Các component đã tạo dùng token/text style có sẵn, Roboto, Auto Layout và icon SVG Lucide. Main component nằm ở frame `55:16`, review dùng instance ở `55:17`. Giữ nguyên placeholder cũ. Màu được bridge bind vào primitive variable theo exact match; semantic aliases có sẵn nhưng chưa được gán trực tiếp cho các node mới. 67/67 typography usage bind text style; 243/243 color usage bind variable. 32 giá trị chưa bind là radius 5 của 7 component set và spacing 0/4. Tích hợp vào 8 màn và prototype là bước tiếp theo.

## Chạy trên file mới hoặc bản sao chưa có thư viện

Không chạy các bước này trên file FLM hiện tại đã có component. Để tiếp tục file hiện tại, dùng bridge ở mục sau; không tạo trùng thư viện.

### Hướng dẫn builder

1. Mở file FLM gốc `N3LyPn9HWDC0M34lVR5jCC` trong Figma Desktop và chọn Design.
2. Vào **Plugins → Development → Import plugin from manifest…**, chọn `manifest.json` trong thư mục này.
3. Chạy plugin **FLM Android Components** từ Plugins → Development.
4. Plugin kiểm tra page, token, text style và Button có sẵn trước khi tạo. Nó không gọi mạng hoặc đọc credential. Nếu có review cùng tên, plugin dừng để tránh tạo trùng.
5. Sau khi tạo, chọn review board để kiểm tra hình ảnh; bấm Download receipt trong cửa sổ plugin và lưu JSON. Chỉ sau bước này mới cập nhật trạng thái thành đã tạo. Nếu plugin lỗi, giữ nguyên thông báo để kiểm tra; chưa ghi nhận là thành công.

## Tiếp tục qua bridge đã cài

Plugin bridge có sẵn tại `C:\Users\LEGION\.codex\tools\figma-mcp-bridge\plugin\manifest.json`, tên **Figma MCP Bridge**. Mở trong Figma Desktop → Plugins → Development để kết nối file với server local. Khi kết nối, agent có thể đọc/ghi và export ảnh thật bằng các tool bridge.

## Các file

- `build-seven.js`: source builder.
- `icons.json`, `icons/`: icon đã pin `lucide-static@0.468.0` từ jsDelivr.
- `code.js`: entry point đóng gói, gồm icon và source. Đã kiểm tra cú pháp bằng `node --check`; đó không phải kiểm thử trong Figma.
- `preview.html`: bản xem trước local; chưa phải export từ canvas.

Đã xem ảnh export thật chứa đủ 7 family/20 trạng thái và sửa icon, căn nhãn nút, kích thước Auto Layout. Bounded validator quét 702 node, không phát hiện lỗi; kiểm thêm 44 target rõ ràng với minimum 48 dp. Kết quả này chỉ áp dụng hai frame thư viện/review, chưa nghiệm thu 360/412 dp toàn app, prototype hay toàn Lab 2. Không đổi Flutter/backend, không commit/push.
