# Figma feedback evidence — 27/10/2026

Ảnh export thật từ file `N3LyPn9HWDC0M34lVR5jCC`, page `03 Final UI`:

- `home-before.png`: Home `2:2470` trước sửa.
- `home-after.png`: cùng Home sau sửa hành trình, font Roboto; ví dụ 1/48 là fixture minh họa. Nội dung cũ giữ tại `86:332`.
- `component-states.png`: board `86:348`, sáu nhóm, state/variant, persona và màn; có 7 instance thư viện.
- `persona-mapping.png`: board `86:543`, nhu cầu/màn và cách đo coverage, nhịp demo.

Figma MCP Bridge đã ghi và đọc lại interactions: `8:117` timeout 3 giây → `8:120`, `86:345` click → `2:2563`, `86:343` click → `2:2777`. Đây là kiểm cấu hình, chưa chạy đủ ba prototype flows.

Apply tokens trong bốn root mới: 134 usages applied, 0 errors; gồm color/radius/spacing/text styles. Bounded validator trên Journey + hai board: 122 nodes, không issue; fixed-text overflow `86:343` chưa xác minh bằng validator. Đã xem ba ảnh sau sửa. Không chứng nhận toàn file/Figma–Flutter parity. Xem `docs/design-traceability.md` cho deviations.

Sau khi gom trang, board `86:348` đã xóa; `component-states.png` giữ làm ảnh lịch sử. Trang hiện hành: `86:558`, ảnh `design-system-one-page.png`.
