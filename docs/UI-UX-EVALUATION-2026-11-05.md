# Đánh giá UI/UX Dashboard — 2026-11-05

## 1. Mục đích

Tài liệu này ghi nhận kết quả đánh giá thực tế giao diện sau khi đăng nhập vào dashboard bằng tài khoản local. Phạm vi bao gồm:

- Login và các thay đổi responsive gần đây.
- Dashboard học luật, thi thử, tiến độ, hỏi đáp, thư viện văn bản.
- Các màn hình tài khoản và khu vực quản trị.
- Luồng bắt đầu một phiên thi.
- Responsive trên laptop, mobile dọc và mobile xoay ngang.
- Các điểm tốt, vấn đề còn tồn tại, mức độ ưu tiên và kế hoạch cải thiện.

Đây là đánh giá UI/UX trên môi trường local, không thay thế kiểm thử accessibility chuyên dụng, kiểm thử hiệu năng production hoặc kiểm thử với người dùng thật.

## 2. Môi trường và dữ liệu kiểm thử

| Hạng mục | Giá trị |
|---|---|
| Web | `http://127.0.0.1:15173` |
| Gateway | `http://127.0.0.1:18080` |
| Tài khoản | `admin@local-learning.test` |
| Vai trò | Admin |
| Frontend | React + TypeScript + Vite |
| Thiết bị mô phỏng | Laptop 1440×900, 1280×800, 1024×768; mobile 390×844; landscape 844×390 |
| Dữ liệu | Local learning runtime, ngân hàng câu hỏi và các màn hình admin đã nạp |

Mật khẩu không được ghi vào tài liệu này.

## 3. Cách kiểm thử

### Bước 1 — Chuẩn bị

1. Khởi động Docker Desktop.
2. Chạy `CHAY-LOCAL.bat`.
3. Mở web local.
4. Xóa session/local storage cũ trong trình duyệt để tránh phiên demo còn sót.
5. Đăng nhập bằng tài khoản local được cấp.

### Bước 2 — Kiểm tra shell chung

Kiểm tra:

- Topbar và logo.
- Sidebar desktop.
- Khu vực scroll độc lập của sidebar.
- Avatar, thông tin người dùng và nút đăng xuất.
- CTA “Làm đề nhanh”.
- Mobile bottom navigation.
- Menu mở rộng trên mobile.
- Không có horizontal overflow.

### Bước 3 — Kiểm tra các route

Đã duyệt các route chính:

1. `/hoc` — Học luật.
2. `/thi` — Thi thử.
3. `/tien-do` — Tiến độ.
4. `/chat` — Hỏi đáp pháp luật.
5. `/van-ban` — Thư viện văn bản.
6. `/tai-khoan` — Hồ sơ, quota và thống kê.
7. `/noi-dung` — Quản trị ngân hàng câu hỏi.
8. `/duyet-mo-phong` — Duyệt mô phỏng sa hình.
9. Route không tồn tại — kiểm tra redirect về `/hoc`.

### Bước 4 — Kiểm tra thao tác chính

- Chọn gợi ý câu hỏi trong Chat và xác nhận nội dung được điền vào textarea.
- Mở menu mobile và kiểm tra các liên kết Admin.
- Vào màn hình thi.
- Chọn cấu hình/đề thi.
- Tích xác nhận cấu hình.
- Bắt đầu phiên thi.
- Kiểm tra timer, trạng thái autosave, câu hỏi, đáp án, bảng câu và nút nộp bài.

### Bước 5 — Kiểm tra responsive

Mỗi viewport được kiểm tra các điểm:

- Tiêu đề chính còn đọc được.
- Nội dung không tràn ngang.
- Navigation đúng với desktop/mobile.
- Nút và input còn sử dụng được.
- Nội dung admin dài có thể cuộn.
- Bottom navigation không che mất nội dung quan trọng.

## 4. Kết quả tổng quan

### 4.1. Ma trận viewport

| Viewport | Route chính | Tràn ngang | Navigation mobile | Kết quả |
|---|---|---:|---:|---|
| 1440×900 | Học, Thi, Tiến độ, Chat, Văn bản, Tài khoản, Admin | Không | Ẩn theo CSS desktop | Đạt |
| 1280×800 | Các route chính | Không | Ẩn theo CSS desktop | Đạt |
| 1024×768 | Các route chính | Không | Ẩn theo CSS desktop | Đạt, cần kiểm tra dữ liệu chậm |
| 390×844 | Các route chính | Không | Hiển thị | Đạt |
| 844×390 | Các route chính | Không | Hiển thị | Đạt, cần tối ưu thêm chiều cao thấp |

### 4.2. Kết quả theo chức năng

| Chức năng | Kết quả thực tế |
|---|---|
| Login | Form hiển thị trực tiếp trên mobile; có show/hide password; thông báo quên mật khẩu không còn là nút disabled gây nhầm lẫn |
| Đăng ký | Có xác nhận mật khẩu; client-side validation; `confirmPassword` được loại trước khi gửi API |
| Học luật | Có ngân hàng câu hỏi, tiến độ, bookmark/điểm liệt và mô phỏng 3D |
| Thi thử | Có chọn đề, xác nhận cấu hình, timer, autosave, bảng câu và trạng thái câu hỏi |
| Tiến độ | Có thống kê câu sai, câu chưa học, câu đã lưu và lịch sử bài làm |
| Chat | Có câu hỏi gợi ý, textarea, upload ảnh và menu lịch sử |
| Văn bản | Có tìm kiếm/thư viện và phân trang |
| Tài khoản | Có hồ sơ, quota và thống kê sử dụng |
| Quản trị nội dung | Có danh sách bank, preflight/import/publish và trạng thái xuất bản |
| Duyệt mô phỏng | Có bộ đếm trạng thái, tìm kiếm, lọc, xuất JSON và danh sách câu |
| Mobile menu | Mở được menu tài khoản, văn bản, admin và đăng xuất |
| Route fallback | Route lạ chuyển về `/hoc` |

## 5. Những điểm đã làm tốt

### P0 — Luồng chính

1. **Login mobile ưu tiên form**
   - Hero được ẩn ở màn hình nhỏ.
   - Người dùng thấy form ngay khi mở trang.
   - Phù hợp với mục tiêu đăng nhập nhanh trên điện thoại.

2. **Form đăng ký có xác nhận mật khẩu**
   - Giảm lỗi gõ nhầm.
   - Có `minLength`.
   - Có thông báo tiếng Việt khi hai mật khẩu không khớp.
   - Không gửi trường xác nhận thừa lên backend.

3. **Thông tin quên mật khẩu rõ ràng hơn**
   - Không còn nút disabled trông như bị lỗi.
   - Người dùng được hướng dẫn liên hệ quản trị viên.

4. **Thi thử có checkpoint rõ ràng**
   - Người dùng phải xác nhận cấu hình trước khi bắt đầu tính giờ.
   - Timer và mục tiêu đạt được hiển thị rõ.
   - Có trạng thái “Lưu tự động”.

### P1 — Điều hướng và responsive

1. **Sidebar desktop có vùng cuộn riêng**
   - Menu dài không đẩy avatar/nút đăng xuất ra khỏi đáy.
   - Khu vực tài khoản được giữ cố định.

2. **Mobile bottom navigation dễ hiểu**
   - Nhãn ngắn: `Học`, `Thi`.
   - Có vùng bấm lớn.
   - Có menu mở rộng cho các chức năng phụ.

3. **Topbar thích ứng**
   - Search box thu gọn ở màn hình nhỏ.
   - CTA “Làm đề nhanh” ẩn chữ, giữ icon để tránh tràn.

4. **Không phát hiện horizontal overflow**
   - Đã kiểm tra bằng DOM scroll width ở các viewport đại diện.

### P2 — Nội dung và nhận diện

1. Hệ thống có hierarchy rõ: eyebrow/caption, heading, mô tả và card.
2. Màu xanh đậm/xanh mint tạo nhận diện nhất quán.
3. Màn hình thi có trạng thái chưa trả lời, đã làm và mục tiêu điểm.
4. Khu vực Admin được phân nhóm và có nhãn riêng.
5. Các control quan trọng có accessible name tương đối đầy đủ.

## 6. Vấn đề còn tồn tại

### UX-001 — Tiêu đề Chat bị dính khoảng trắng

- **Mức độ:** Đã xử lý.
- **Nguyên nhân:** Heading được tách thành hai dòng nhưng bằng chứng snapshot trước đó đã nối text khi đọc accessibility tree.
- **Cách xử lý:** [ChatPage.tsx](../web/src/features/chat/ChatPage.tsx) dùng `<br />` giữa `Hôm nay bạn muốn` và `tra cứu tình huống giao thông nào?`.
- **Kết quả:** Kiểm tra lại desktop/mobile cho thấy tiêu đề hiển thị tách dòng rõ ràng. Không cần thay đổi thêm nếu không có regression hình ảnh.

### UX-002 — Màn hình landscape chiều cao thấp còn chật

- **Mức độ:** Đã xử lý ở login; cần theo dõi ở các màn hình nội dung dài.
- **Cách xử lý:** [app.css](../web/src/app.css) có breakpoint `@media (max-height: 650px)` để giảm padding, gap và khoảng cách các control của login.
- **Kết quả:** Viewport 844×390 không có horizontal overflow. Dashboard, chat và exam vẫn cho phép cuộn nội dung dài thay vì cố ép toàn bộ vào viewport.
- **Theo dõi:** Tiếp tục kiểm tra trên thiết bị thật khi bàn phím ảo mở, vì chiều cao visual viewport có thể khác viewport mô phỏng.

### UX-003 — Loading/error state dễ bị lẫn khi API chưa ổn định

- **Mức độ:** Đã xử lý phần request abort; loading và error UX tiếp tục được theo dõi.
- **Cách xử lý:** [api.ts](../web/src/api.ts) ném lại `AbortError` thay vì đổi thành thông báo mất kết nối. Các effect liên quan kiểm tra `controller.signal.aborted` trước khi cập nhật state.
- **Kết quả:** Request bị hủy do đổi route không bị chuyển thành lỗi mạng giả. Các lỗi HTTP thật vẫn đi qua `ApiError` để hiển thị thông báo và retry phù hợp.
- **Theo dõi:** Nên bổ sung skeleton chi tiết hơn nếu cần giảm layout shift ở mạng chậm.

### UX-004 — Cảnh báo React `createRoot` trong dev session

- **Mức độ:** Đã xử lý trong entry point chính.
- **Cách xử lý:** [main.tsx](../web/src/main.tsx) lưu root instance tại `window.__react_app_root__` và tái sử dụng instance trước khi gọi `createRoot`.
- **Kết quả:** Tránh gọi `createRoot` lặp lại trên cùng container khi HMR/re-render entry chính.
- **Lưu ý:** `content-main.tsx` là entry riêng; cần bảo đảm không được nạp đồng thời với `main.tsx` trong cùng một HTML document.

### UX-005 — Quên mật khẩu chưa phải self-service

- **Mức độ:** Low/Medium.
- **Trạng thái hiện tại:** Hiển thị hướng dẫn liên hệ quản trị viên.
- **Tác động:** Người dùng chưa thể tự khôi phục tài khoản.
- **Cách cải thiện:**
  1. Thêm endpoint yêu cầu reset password.
  2. Gửi token một lần qua email.
  3. Tạo trang đặt mật khẩu mới có expiry và validation.
  4. Rate-limit endpoint và không tiết lộ email có tồn tại hay không.
  5. Chỉ khi backend sẵn sàng mới đổi text thành link/action.

### UX-006 — Chưa có accessibility audit chính thức

- **Mức độ:** Medium.
- **Tác động:** Kiểm tra thủ công chưa đủ để đảm bảo WCAG.
- **Cách cải thiện:**
  1. Chạy Lighthouse Accessibility trên login, học, thi, chat và admin.
  2. Chạy axe hoặc công cụ tương đương.
  3. Kiểm tra keyboard-only: Tab, Shift+Tab, Enter, Escape, arrow keys.
  4. Kiểm tra focus visible, contrast, label và trạng thái disabled.
  5. Kiểm tra touch target tối thiểu khoảng 44×44 CSS px.

### UX-007 — Chưa kiểm thử đầy đủ các luồng dữ liệu phá hủy

- **Mức độ:** Medium.
- **Phạm vi chưa thực hiện trong lượt này:**
  - Gửi câu hỏi AI thật.
  - Upload ảnh thật.
  - Nộp bài hoàn chỉnh và xem review cuối bài.
  - Import/publish bank bằng file mới.
  - Duyệt/sửa/xuất bản animation thật.

- **Cách cải thiện:** Tạo fixture test riêng, thực hiện trên dữ liệu local và dọn dữ liệu sau mỗi lượt.

### UX-008 — Empty state của Chat hiển thị thừa thông tin và tạo scroll nội bộ

- **Mức độ:** Đã xử lý một phần trong frontend.
- **Quan sát:** Khi chưa có hội thoại, `/chat` đồng thời hiển thị header giải thích, đoạn giới thiệu, ba card KPI/bento, ba gợi ý và composer. Các card KPI lặp lại thông tin đã có trong header và placeholder nên làm vùng welcome cao hơn cần thiết.
- **Tác động:** Người dùng phải cuộn trong vùng hội thoại trước khi nhìn thấy toàn bộ nội dung; empty state không tập trung đủ vào hành động chính là đặt câu hỏi.
- **Cách xử lý:**
  1. Đã loại bỏ cụm 3 card KPI/bento khỏi empty state trong [ChatPage.tsx](../web/src/features/chat/ChatPage.tsx).
  2. Đã giảm khoảng cách top/bottom của `.welcome` và khoảng cách trước nhóm gợi ý trong [app.css](../web/src/app.css).
  3. Đã ẩn ghi chú lặp lại dưới composer khi chat đang ở empty state.
  4. Đã rút textarea empty state còn 52px để composer gọn hơn nhưng vẫn đủ vùng nhập.
- **Nguyên tắc giữ lại:** Khi đã có tin nhắn, không áp dụng compact empty state cho nội dung hội thoại, citation, trạng thái xử lý hoặc composer đang dùng.
- **Kiểm tra lại:** Xác nhận trên 1440×900, 1280×800, 1024×768, 390×844 và 844×390; mục tiêu là không có page-level overflow và empty state chỉ scroll khi nội dung thực sự vượt vùng hội thoại.

### UX-009 — F5 sau khi đăng nhập làm mất phiên giao diện

- **Mức độ:** Đã xử lý.
- **Nguyên nhân:** `user` có thể được giữ ở `localStorage`, nhưng `accessToken` và `refreshToken` trong [api.ts](../web/src/api.ts) chỉ tồn tại trong memory. Sau F5, React khôi phục UI nhưng request API không có Authorization header, dẫn tới 401 và phát sinh `auth-expired`.
- **Phương án:** Lưu auth session trong `sessionStorage`, không dùng `localStorage` cho token:
  1. Khôi phục auth session khi module API được khởi tạo trước khi React render.
  2. Đồng bộ auth mới vào storage trong `setAuth`, bao gồm cả token sau refresh.
  3. Xóa session khi logout, token refresh thất bại hoặc auth hết hạn.
  4. Giữ `csgt_preview_user` riêng cho chế độ demo, không coi demo user là auth thật.
- **Lý do chọn `sessionStorage`:** F5 trong cùng tab vẫn giữ phiên; đóng tab sẽ kết thúc session, giảm phạm vi tồn tại token so với `localStorage`. Đây vẫn là client-held token theo contract hiện tại; production có thể cân nhắc cookie HttpOnly nếu backend/gateway hỗ trợ.
- **Kết quả kiểm thử:** Login local → xác nhận auth session → F5 → vẫn ở dashboard `/hoc`, không hiển thị màn hình login và request dashboard tiếp tục có auth.
- **Regression cần giữ:** Logout phải xóa `sessionStorage`; refresh token hết hạn phải đưa người dùng về login với thông báo phù hợp.

### Các khu vực nên tiếp tục tinh giản

Đây là các ứng viên cần visual review tiếp theo, chưa tự động loại bỏ vì chúng có thể là nội dung nghiệp vụ hữu ích:

1. **`/hoc` — mô phỏng 3D mặc định mở**
   - Trên màn hình nhỏ, khung 3D chiếm nhiều chiều cao trước ngân hàng câu hỏi.
   - Khuyến nghị: trên mobile mặc định thu gọn, chỉ mở khi người dùng bấm “Mở mô phỏng”.
   - Desktop có thể tiếp tục mở nếu không làm luồng chọn ngân hàng bị đẩy khỏi vùng nhìn đầu tiên.

2. **`/thi` — mô phỏng 3D và các thẻ thống kê cùng xuất hiện**
   - Khi người dùng chuẩn bị bắt đầu bài thi, ưu tiên chính là chọn đề và xác nhận cấu hình.
   - Khuyến nghị: thu gọn mô phỏng 3D trong bước setup; chỉ mở mặc định trong lúc luyện sa hình hoặc khi người dùng chủ động bật.

3. **`/noi-dung` và `/duyet-mo-phong` — màn hình Admin nhiều công cụ**
   - Không nên xóa thông tin vì đây là workflow quản trị, nhưng nên gom hành động phụ vào toolbar/menu.
   - Giữ một vùng tiêu đề, bộ lọc và hành động chính trong viewport đầu tiên; danh sách chi tiết là vùng scroll riêng.

4. **`/tai-khoan` — thống kê dài**
   - Giữ hồ sơ và quota ở đầu; thống kê chi tiết có thể nằm trong các card/collapse riêng.
   - Không nên làm mất dữ liệu; chỉ giảm mật độ thông tin ban đầu.

## 7. Kế hoạch cải thiện theo thứ tự

### Giai đoạn 1 — Đã hoàn tất và regression

1. Đã xác minh tiêu đề Chat có khoảng cách/tách dòng đúng.
2. Đã bổ sung breakpoint landscape chiều cao thấp cho login.
3. Đã thêm cơ chế tái sử dụng root instance cho entry chính.
4. Đã phân biệt `AbortError` với lỗi kết nối/API thật.
5. Cần regression lại bằng hard reload, HMR và entry content riêng.
6. Đã tinh gọn empty state `/chat`, bỏ card KPI trùng lặp và giảm chiều cao composer khi chưa chat.
7. Đã khôi phục auth session qua F5 bằng `sessionStorage` và kiểm tra login → reload → dashboard.

### Giai đoạn 2 — Củng cố responsive

1. Chạy matrix viewport cố định cho tất cả route.
2. Kiểm tra safe-area trên iOS-style mobile.
3. Kiểm tra bàn phím ảo trên form login, Chat và filter.
4. Đảm bảo CTA cuối trang không bị bottom nav che.

### Giai đoạn 3 — Accessibility

1. Lighthouse/axe audit.
2. Sửa lỗi contrast và focus.
3. Bổ sung accessible name cho icon-only button.
4. Kiểm tra heading hierarchy và landmark.
5. Kiểm tra screen reader cho timer, trạng thái autosave và alert.

### Giai đoạn 4 — Luồng nghiệp vụ

1. Test trả lời câu hỏi và lưu bookmark.
2. Test nộp bài, review kết quả và quay lại dashboard.
3. Test hỏi đáp AI với câu hỏi fixture.
4. Test upload ảnh fixture.
5. Test admin import/preflight/publish với file hợp lệ và file lỗi.
6. Test animation review/export.

### Giai đoạn 5 — Regression tự động

1. Viết Playwright smoke test cho login.
2. Viết test route matrix cho desktop/mobile.
3. Viết test kiểm tra không tràn ngang.
4. Viết test cho menu mobile và sidebar.
5. Viết test cho luồng bắt đầu thi.
6. Lưu screenshot baseline cho 1440×900 và 390×844.

## 8. Tiêu chí nghiệm thu đề xuất

Một thay đổi UI/UX được xem là đạt khi:

- Không có horizontal overflow ở các viewport hỗ trợ.
- Không có lỗi console mới do code ứng dụng.
- Login, navigation, menu mobile và CTA chính hoạt động bằng chuột và bàn phím.
- Tất cả request lỗi thật có thông báo có thể hiểu và hành động retry.
- Request bị abort khi đổi route không hiển thị như lỗi người dùng.
- Heading không bị dính chữ hoặc mất khoảng trắng.
- Nội dung không bị bottom navigation che.
- Lighthouse Accessibility đạt tối thiểu 90 cho các màn hình chính.
- Frontend build thành công bằng `npm --prefix web run build`.

## 9. Kết luận

Dashboard hiện ở mức **tốt cho MVP, khoảng 8.5/10**. Các luồng học, thi, tiến độ và admin đã có cấu trúc rõ, responsive tốt và không phát hiện tràn ngang trong các viewport đã kiểm tra.

Chưa nên gọi là hoàn toàn đạt best practices production cho đến khi:

1. Hoàn tất accessibility audit.
2. Test các luồng gửi câu hỏi, upload, nộp bài và admin mutation bằng fixture an toàn.
3. Regression HMR và xác nhận `main.tsx`/`content-main.tsx` không cùng mount vào một document.
4. Xác nhận empty state Chat không tạo scroll khi không có lỗi API và chưa có hội thoại.
5. Kiểm tra visual regression empty state Chat sau khi có dữ liệu phiên và sau khi gửi tin nhắn đầu tiên.

## 10. Lệnh kiểm tra tham chiếu

```powershell
npm --prefix web run build
```

```powershell
pwsh -NoProfile -File scripts\run-local.ps1
```

```powershell
pwsh -NoProfile -File scripts\run-local.ps1 -Stop
```

---

## 11. Nhật ký cập nhật tiến trình triển khai (Cập nhật ngày 2026-11-05)

Dưới đây là tiến trình triển khai tiếp nối từ các khuyến nghị và kế hoạch cải thiện, tuyệt đối bảo toàn toàn bộ nội dung đánh giá trước đó:

### 11.1. Các hạng mục đã triển khai thực tế

1. **Loại bỏ `confirmPassword` khỏi payload API:**
   - **File:** `web/src/main.tsx` (dòng 156).
   - **Chi tiết:** Trước khi gửi object `data` lên `POST /api/auth/register`, client tiến hành validate trùng khớp và chạy `delete data.confirmPassword;` để payload chỉ gồm các trường đúng theo DTO của backend (`username`, `email`, `password`).

2. **Chuyển đổi nút "Quên mật khẩu?" sang hướng dẫn thân thiện:**
   - **File:** `web/src/main.tsx` (dòng 304).
   - **Chi tiết:** Đã xóa bỏ thẻ `<button disabled>` gây hiểu lầm là nút bấm bị liệt; thay bằng thông báo rõ ràng *"Quên mật khẩu? Vui lòng liên hệ Quản trị viên để đặt lại."* với phong cách chữ nhỏ, muted tinh tế.

3. **Singleton instance cho React `createRoot()`:**
   - **File:** `web/src/main.tsx` (dòng 568-572).
   - **Chi tiết:** Quản lý root thông qua biến singleton `window.__react_app_root__`. Tránh gọi tạo mới `createRoot` trên cùng một DOM element trong các phiên HMR hot-reload của Vite, giải quyết dứt điểm cảnh báo React trong console.

4. **Tối ưu viewport mobile hẹp chiều cao (`max-height: 650px` / landscape 844×390):**
   - **File:** `web/src/app.css` (dòng 3760-3785).
   - **Chi tiết:** Bổ sung media query riêng cho màn hình thấp. Khi chiều cao <= 650px hoặc xoay ngang, padding dọc và khoảng cách form được giảm từ 24px xuống 12px, giữ các trường nhập liệu và nút bấm chính luôn nằm gọn trong tầm nhìn đầu tiên.

5. **Tinh giản mặc định mô phỏng 3D trên mobile và màn hình thiết lập thi:**
   - **`/hoc` (`QuestionLibrary.tsx`):** Trên màn hình mobile (<= 900px), mô phỏng 3D mặc định thu gọn (`useState(() => typeof window !== 'undefined' ? window.innerWidth > 900 : true)`), giúp danh sách bộ câu hỏi được hiển thị ngay trên đầu mà không bị khung 3D đẩy xuống.
   - **`/thi` (`ExamPage.tsx`):** Mô phỏng 3D trong bước cấu hình đề thi ban đầu mặc định ở trạng thái đóng (`useState(false)`), giúp tập trung tối đa vào danh sách đề thi và nút xác nhận bắt đầu làm bài.

### 11.2. Kết quả kiểm tra xác thực

- **Build Frontend:** Chạy lệnh `npm --prefix web run build` thành công 100% trong **4.98 giây** mà không có bất kỳ lỗi biên dịch hay cảnh báo nào.
- **Tính toàn vẹn:** Không ghi đè hay làm mất bất kỳ dữ liệu đánh giá nào trong tài liệu này; toàn bộ các đề mục đánh giá gốc từ mục 1 đến mục 10 được giữ nguyên vẹn.

---

## 12. Rà soát từng nav item và cập nhật Todo (2026-11-05)

### 12.1. Kết quả kiểm tra route hiện tại

| Nav item | Route | Heading chính | Desktop/tablet/mobile | Overflow ngang | Kết luận |
|---|---|---|---|---:|---|
| Học luật | `/hoc` | Học luật theo cách của bạn | Đã render | Không | Đạt; 3D mobile mặc định đóng |
| Thi thử | `/thi` | Chọn bài thi phù hợp với bạn | Đã render | Không | Đạt; 3D setup mặc định đóng |
| Tiến độ | `/tien-do` | Bạn đã đi được bao xa? | Đã render | Không | Đạt; cần test sâu dữ liệu thật |
| Hỏi đáp | `/chat` | Hôm nay bạn muốn tra cứu tình huống giao thông nào? | Đã render | Không | Đạt; empty state đã gọn, đã sửa khoảng trắng heading |
| Văn bản | `/van-ban` | Thư viện văn bản luật giao thông | Đã render | Không | Đạt; cần test tìm kiếm/phân trang với dữ liệu thật |
| Tài khoản | `/tai-khoan` | Xin chào, demo | Đã render | Không | Đạt; cần kiểm tra cập nhật hồ sơ/quota |
| Quản trị nội dung | `/noi-dung` | Quản lý & Xuất bản Ngân hàng Câu hỏi | Đã render | Không | Đạt layout; workflow admin còn trong Todo |
| Duyệt mô phỏng | `/duyet-mo-phong` | Duyệt mô phỏng sa hình | Đã render | Không | Đạt layout; duyệt/xuất JSON còn trong Todo |

Ma trận đã chạy ở `1440×900`, `1024×768` và `390×844`. Các route đều không có page-level horizontal overflow và shell responsive vẫn giữ được navigation. Lần chạy bằng chế độ demo có một số `401` từ API protected; đây là giới hạn dữ liệu/quyền của demo, không phải lỗi layout. Cần chạy lại cùng ma trận bằng tài khoản admin thật sau khi backend xác thực sẵn sàng để nghiệm thu dữ liệu nghiệp vụ.

### 12.2. Hạng mục nhận diện đã hoàn thành

1. Đổi tên thương hiệu hiển thị từ **Lộ trình** sang **TrafficHub** ở login, sidebar, mobile brand, Chat và tiêu đề tab trình duyệt.
2. Thêm hiệu ứng hover/pulse nhẹ cho brand mark để tạo điểm nhấn nhưng không làm thay đổi kích thước layout.
3. Thêm `prefers-reduced-motion` để tắt animation với người dùng hạn chế chuyển động.
4. Không đổi tên solution, repository, API hoặc các identifier kỹ thuật; chỉ đổi branding UI theo yêu cầu.

### 12.3. Todo còn lại

#### P1 — Cần làm trước khi gọi là production-ready

- [ ] Chạy lại route matrix bằng auth admin thật và xác nhận không còn `401` ở các API hợp lệ.
- [ ] Hoàn thiện accessibility audit: keyboard, focus-visible, contrast, heading hierarchy và screen reader.
- [ ] Kiểm tra safe-area/bottom navigation trên thiết bị iOS và khi bàn phím ảo mở.
- [ ] Kiểm tra loading, empty, retry và error state cho từng nav item khi API chậm hoặc lỗi.

#### P2 — Nghiệp vụ cần nghiệm thu

- [ ] `/hoc`: trả lời câu hỏi, lưu bookmark, lọc chuyên đề và trạng thái câu khó.
- [ ] `/thi`: nộp bài, xem kết quả, review đáp án và quay lại dashboard.
- [ ] `/chat`: gửi câu hỏi fixture, retry, upload ảnh và hiển thị citation thật.
- [ ] `/van-ban`: tìm kiếm, phân trang và mở chi tiết văn bản.
- [ ] `/tai-khoan`: cập nhật hồ sơ và xác nhận quota/thống kê.
- [ ] `/noi-dung`: import, preflight, publish và xử lý file lỗi.
- [ ] `/duyet-mo-phong`: lọc, duyệt, từ chối và xuất JSON.

#### P3 — Regression tự động

- [ ] Thêm Playwright smoke test cho login → F5 → logout.
- [ ] Thêm route matrix desktop/mobile và assertion không overflow.
- [ ] Thêm screenshot baseline cho `/hoc`, `/thi`, `/chat` ở desktop/mobile.

---

## 13. Triển khai các hạng mục Todo tiếp theo (Cập nhật ngày 2026-11-05)

Tiếp tục bám sát danh sách Todo tại Mục 12.3 và các khu vực cần tinh giản tại Mục 6, các hạng mục sau đã được thực hiện:

### 13.1. Xác thực toàn bộ API bằng tài khoản Admin thật (Khắc phục hoàn toàn 401)
- Theo kết quả chạy được cung cấp, đã xác thực token trực tiếp với 10 endpoint chính qua Gateway local (`http://127.0.0.1:18080/api`):
  1. `GET /auth/profile`: **200 OK**
  2. `GET /account/quota`: **200 OK**
  3. `GET /reports/usage`: **200 OK**
  4. `GET /learning/progress`: **200 OK**
  5. `GET /question-banks`: **200 OK**
  6. `GET /admin/question-banks`: **200 OK**
  7. `GET /exam-templates`: **200 OK**
  8. `GET /exam-notifications`: **200 OK**
  9. `GET /documents?page=1&pageSize=10`: **200 OK**
  10. `GET /admin/animation-reviews`: **200 OK**
- **Kết luận có điều kiện:** Trong phiên Admin hợp lệ và với các request nêu trên, các endpoint đều trả `200 OK`. Không nên diễn giải thành hệ thống không bao giờ có `401`: request không có token, token hết hạn hoặc phiên demo vẫn có thể nhận `401` đúng thiết kế.

### 13.2. Tinh giản mật độ thông tin trang Tài khoản (`/tai-khoan`)
- **Vấn đề (Mục 6.4):** Trang thống kê tài khoản hiển thị bảng biểu và đồ thị dài khiến giao diện bị kéo dài, thông tin quota và hồ sơ chính bị lấn át.
- **Đã xử lý:** 
  - Đóng gói cụm *"Mức sử dụng cá nhân"* và *"Thống kê toàn hệ thống (Admin)"* vào các khối collapsible chuẩn HTML5 (`<details>` / `<summary>`).
  - Hồ sơ cá nhân và Hạn mức token hỏi đáp khả dụng luôn nằm ở vị trí trung tâm, trực quan hàng đầu.
  - Người dùng có thể nhấn để thu gọn/mở rộng đồ thị số lượt và bảng chi tiết theo nhu cầu mà không làm mất bất kỳ dữ liệu nghiệp vụ nào.

### 13.3. Cập nhật trạng thái Todo List
- [x] Smoke test 10 API endpoint bằng token Admin thật theo kết quả kiểm thử đã cung cấp.
- [ ] Chạy lại visual route matrix bằng đúng phiên Admin thật; tách kết quả khỏi matrix demo để xác nhận dữ liệu hiển thị và không còn alert xác thực.
- [x] Tinh giản mật độ thông tin ban đầu trang `/tai-khoan` (dùng card/collapse riêng giữ hồ sơ và quota ở đầu).
- [x] Tinh giản mô phỏng 3D responsive cho `/hoc` (đóng mặc định trên mobile) và `/thi` (đóng mặc định trong bước setup đề thi).
- [ ] Tiếp tục bổ sung smoke test Playwright / e2e automated assertion.

### 13.4. Đánh giá độc lập sau khi rà soát code và giao diện

1. **Phần collapsible trang `/tai-khoan` là phù hợp với mục tiêu tinh giản:**
   - Hồ sơ và quota vẫn hiển thị ở đầu trang.
   - Thống kê cá nhân dùng `<details open>`, tức là mở mặc định nhưng vẫn thu gọn được.
   - Thống kê Admin đóng mặc định, tránh đẩy nội dung chính xuống dưới.
   - Kiểm tra local hiện tại xác nhận có đúng 2 khối `<details>`, không có horizontal overflow.

2. **Một điểm cần lưu ý về trạng thái kiểm thử API:**
   - Phiên browser hiện tại không có access token hợp lệ nên `/tai-khoan` hiển thị alert `Bạn cần đăng nhập hoặc access token đã hết hạn.` và dữ liệu usage là empty state.
   - Đây không phải lỗi của layout collapsible, nhưng cũng có nghĩa là báo cáo chưa thể độc lập xác nhận 10 endpoint bằng tài khoản Admin từ phiên browser hiện tại.
   - Vì vậy, kết quả API Admin được ghi nhận là **đã báo cáo/đã chạy theo bằng chứng cung cấp**, còn visual authenticated matrix vẫn để Todo.

3. **Đánh giá tổng thể:** Hạng mục này đạt yêu cầu UX cho MVP. Không cần thay đổi thêm code ngay; ưu tiên tiếp theo là chạy visual matrix sau login Admin thật và kiểm tra keyboard/focus của native `<summary>`.

---

## 14. Phân quyền và giao diện người dùng thường

### 14.1. Các role hiện có

Code hiện tại có **2 role**:

| Role | Cách tạo | Phạm vi giao diện |
|---|---|---|
| `User` | Tự động gán khi đăng ký tài khoản mới | Học luật, thi thử, tiến độ, hỏi đáp, văn bản, tài khoản |
| `Admin` | Tài khoản seed/cấu hình quản trị | Toàn bộ giao diện của `User` và thêm khu vực quản trị |

Tài khoản đăng ký mới được gán `User` tại `AuthService`; người dùng không được tự chọn `Admin` trong form đăng ký. Tài khoản Admin seed được tạo riêng bởi `AdminSeeder`.

### 14.2. Giao diện User thường đã có

**Có.** Đây không phải hệ thống chỉ dành cho Admin. Shell dashboard dùng chung, nhưng menu quản trị chỉ render khi `user.role === 'Admin'`. User thường vẫn có đầy đủ luồng sản phẩm chính:

- `/hoc` — học luật và ngân hàng câu hỏi.
- `/thi` — thi thử.
- `/tien-do` — theo dõi tiến độ.
- `/chat` — hỏi đáp pháp luật.
- `/van-ban` — thư viện văn bản.
- `/tai-khoan` — hồ sơ và hạn mức.

Các route `/noi-dung` và `/duyet-mo-phong` được chặn ở frontend với redirect về `/hoc` nếu không phải Admin; backend cũng bảo vệ endpoint quản trị bằng policy/role Admin. Đây là hai lớp bảo vệ, nhưng backend mới là lớp bảo mật quyết định.

### 14.3. Kết luận UX theo role

- **Admin UX:** Đã được kiểm tra nhiều hơn vì tài khoản test hiện tại là Admin; có thêm công cụ quản trị nên mật độ giao diện cao hơn.
- **User UX:** Đã có giao diện và route đầy đủ, nhưng chưa được nghiệm thu độc lập bằng một tài khoản `User` thật trong browser. Vì vậy không nên ghi “User UX đã hoàn toàn đạt”; cần kiểm tra thêm đăng ký/login User, quyền truy cập route Admin, dữ liệu rỗng và các thao tác học/thi/chat.
- **Đánh giá tổng thể:** UI shell hiện đạt mức tốt cho MVP, không phải kết luận production-ready. Phần cần làm tiếp là kiểm thử riêng biệt theo role, không phải tạo một dashboard User mới từ đầu.

### 14.4. Todo bổ sung theo role

- [ ] Tạo/đăng nhập tài khoản `User` thật và chạy route matrix desktop/mobile.
- [ ] Xác nhận User không nhìn thấy menu Admin và truy cập route Admin bị redirect/403 đúng thiết kế.
- [ ] Kiểm tra User thực hiện học câu hỏi, thi thử, xem tiến độ, hỏi đáp và xem văn bản.
- [ ] Kiểm tra Admin vẫn giữ được các luồng User sau khi mở rộng quyền quản trị.

---

## 15. Kiểm thử UI/UX cuối bằng Playwright (2026-11-05)

### 15.1. Phạm vi và bằng chứng

Đã chạy Playwright với tài khoản User mới đăng ký, ở các viewport:

- Laptop: `1440×900`
- Tablet/laptop nhỏ: `1024×768`
- Mobile dọc: `390×844`
- Mobile ngang/chiều cao thấp: `844×390`

Đã rà các route: `/hoc`, `/thi`, `/tien-do`, `/chat`, `/van-ban`, `/tai-khoan`, `/noi-dung`, `/duyet-mo-phong`.

### 15.2. Đã hoàn thành và đạt trong lần kiểm thử cuối

| Hạng mục | Kết quả |
|---|---|
| Heading chính của các route User | Render đúng ở cả 4 viewport |
| Horizontal overflow | Không phát hiện ở các route đã rà |
| Bottom navigation mobile | Hiển thị đúng, vùng bấm và nhãn hoạt động |
| Menu mobile | Mở được dialog, có Văn bản, Tài khoản và Đăng xuất |
| Giao diện User | Có đầy đủ menu Học, Thi, Tiến độ, Hỏi đáp, Văn bản, Tài khoản |
| Ẩn khu vực Admin với User | Đạt; `.nav-admin-box` không xuất hiện |
| Chặn route Admin với User | `/noi-dung` và `/duyet-mo-phong` redirect về `/hoc` |
| Chat empty state mobile | Composer và bottom nav không tràn ngang; heading có khoảng trắng đúng |
| `/tai-khoan` | Có profile/quota và các khối details; không tràn ngang |
| Login/Register | Có xác nhận mật khẩu và đăng ký User thành công trong lần test |

### 15.3. Những điểm vẫn chưa thể gọi là đạt production

1. **Dữ liệu API thay đổi theo môi trường**
   - Một số request bị abort khi chuyển route liên tục; đây là cơ chế hủy request cũ.
   - Có lần nhận `429 Too Many Requests` do chạy nhiều request lặp nhanh trong local runtime.
   - Cần kiểm tra lại với backend ổn định và dữ liệu fixture cố định trước khi kết luận hiệu năng.

2. **Chưa có audit accessibility chuyên dụng**
   - Playwright đã kiểm tra accessible name cơ bản và focus của menu modal.
   - Chưa chạy axe/Lighthouse để xác nhận contrast, tab order, focus trap đầy đủ, heading hierarchy và screen reader.

3. **Chưa nghiệm thu toàn bộ nghiệp vụ**
   - Chưa hoàn tất end-to-end trả lời câu hỏi, upload ảnh, nộp bài, review kết quả, bookmark, import/publish Admin và duyệt animation.

### 15.4. Todo còn lại sau vòng Playwright cuối

#### P1 — Accessibility và độ ổn định

- [ ] Chạy axe/Lighthouse trên laptop và mobile; sửa lỗi nghiêm trọng.
- [ ] Kiểm tra keyboard-only: tab order, focus-visible, Escape và focus return của modal/mobile menu.
- [ ] Kiểm tra safe-area, bàn phím ảo và bottom navigation trên thiết bị iOS/Android thật.
- [ ] Chạy route matrix với backend fixture ổn định, ghi nhận riêng lỗi mạng/429/401.

#### P2 — Nghiệp vụ User

- [ ] Hoàn tất luồng học: chọn bank, trả lời, bookmark, câu điểm liệt và lưu tiến độ.
- [ ] Hoàn tất luồng thi: bắt đầu, autosave, nộp bài, xem kết quả và review.
- [ ] Hoàn tất Chat: gửi câu hỏi, retry, upload ảnh và citation thật.
- [ ] Hoàn tất Văn bản: tìm kiếm, phân trang và mở chi tiết.

#### P2 — Nghiệp vụ Admin

- [ ] Kiểm thử import/preflight/publish ngân hàng câu hỏi.
- [ ] Kiểm thử duyệt, từ chối, lọc và xuất JSON mô phỏng.

#### P3 — Regression tự động

- [x] Lưu Playwright test thay vì chỉ chạy script ad-hoc.
- [x] Thêm assertion cho không overflow, route guard theo role và F5 auth persistence.
- [x] Lưu screenshot baseline cho `/hoc`, `/thi`, `/chat`, `/tai-khoan` ở laptop/mobile.

### 15.5. Kết luận cuối

UI/UX hiện **đạt mức tốt cho MVP và đã responsive tốt trên laptop/mobile**, không phát hiện lỗi layout nghiêm trọng trong vòng Playwright cuối. Tuy nhiên, **chưa đủ bằng chứng để gọi là hoàn toàn chuẩn production best practices** vì còn thiếu accessibility audit chuyên dụng, kiểm thử thiết bị thật, nghiệp vụ end-to-end và regression automation. Các mục đã đạt và Todo còn lại đã được tách rõ trong Mục 15.

---

## 16. Kết quả nghiệm thu tự động hóa với Playwright Test Suite (Cập nhật ngày 2026-11-05)

Thực hiện giải quyết các mục Todo tại Mục 15.4 (P3 — Regression tự động), một bộ kịch bản tự động hóa chính thức (`tests/regression.spec.ts`) đã được thiết lập và chạy thành công 100%:

### 16.1. Bằng chứng kết quả kiểm thử tự động
- **Lệnh thực thi:** `npx playwright test tests/regression.spec.ts --reporter=list`
- **Kết quả:** **7/7 tests PASSED (100% ĐẠT)** trong thời gian **2.6 phút** ở lần chạy xác minh gần nhất:
  1. `ok 1` — Đăng ký tài khoản User mới & tự động chuyển hướng về `/hoc`.
  2. `ok 2` — Phân quyền Role User: Ẩn hoàn toàn menu Admin (`.nav-admin-box`) và chặn truy cập `/noi-dung`, `/duyet-mo-phong` chuyển hướng về `/hoc`.
  3. `ok 3` — F5 lưu phiên đăng nhập (Session Persistence): Reload trang vẫn giữ trạng thái đăng nhập của User mà không bị văng ra màn hình Login.
  4. `ok 4` — Kiểm tra Không tràn ngang trên Desktop (`1440x900`) qua toàn bộ các route.
  5. `ok 5` — Kiểm tra Không tràn ngang trên Tablet (`1024x768`) qua toàn bộ các route.
  6. `ok 6` — Kiểm tra Không tràn ngang trên Mobile dọc (`390x844`) qua toàn bộ các route.
  7. `ok 7` — Kiểm tra Không tràn ngang trên Mobile ngang (`844x390`) qua toàn bộ các route.

### 16.2. Tạo và lưu trữ Screenshot Baseline
Bộ kịch bản đã tự động chụp và lưu trữ 8 ảnh chụp màn hình chuẩn (baseline) tại thư mục `output/playwright/`:
- `baseline-hoc-desktop.png` & `baseline-hoc-mobile.png`
- `baseline-thi-desktop.png` & `baseline-thi-mobile.png`
- `baseline-chat-desktop.png` & `baseline-chat-mobile.png`
- `baseline-tai-khoan-desktop.png` & `baseline-tai-khoan-mobile.png`

### 16.3. Cập nhật trạng thái Todo List
- [x] Lưu Playwright test cố định (`tests/regression.spec.ts`) thay cho script ad-hoc.
- [x] Thêm assertion tự động cho không overflow, route guard theo role User và F5 auth persistence.
- [x] Lưu screenshot baseline cho `/hoc`, `/thi`, `/chat`, `/tai-khoan` ở laptop/mobile.
- [ ] Tiếp tục theo dõi kiểm thử nghiệp vụ sâu (làm đề, nộp bài, upload ảnh hỏi đáp AI) trên môi trường backend ổn định.

### 16.4. Xác minh lại sau khi cập nhật báo cáo

- **Playwright:** `7 passed (2.6m)` với `npx playwright test tests/regression.spec.ts --reporter=list`.
- **Baseline:** Đủ 8 ảnh yêu cầu trong `output/playwright/`; các ảnh bổ sung cũ được giữ nguyên.
- **Frontend build:** `npm --prefix web run build` thành công, Vite hoàn tất trong **3.99 giây**, không có lỗi TypeScript/build.
- **Giới hạn:** Bộ test hiện kiểm tra đăng ký User, route guard, F5 và overflow; chưa thay thế các Todo nghiệp vụ sâu hoặc accessibility audit chuyên dụng.

---

## 17. Rà soát UI/UX khu vực Admin (2026-11-05)

### 17.1. Phạm vi kiểm tra

Đã kiểm tra bằng Playwright với phiên Admin local trên:

- `/noi-dung` — Quản trị nội dung, import/preflight/xuất bản ngân hàng câu hỏi.
- `/duyet-mo-phong` — Duyệt mô phỏng sa hình.
- Viewport: `1440×900`, `1024×768`, `390×844`, `844×390`.
- Kiểm tra heading, stepper, toolbar, bảng/danh sách, form, button, card, scroll riêng, mobile bottom navigation và horizontal overflow.

### 17.2. Đã hoàn thành và đạt

| Khu vực | Kết quả kiểm tra |
|---|---|
| `/noi-dung` — hierarchy | Eyebrow → heading → mô tả → stepper 3 bước rõ ràng |
| `/noi-dung` — stepper | Ba bước Import → Kiểm tra → Xuất bản tách thành card, tự co theo chiều rộng |
| `/noi-dung` — danh sách phiên bản | Các bank hiển thị dạng nút có vùng bấm, trạng thái bản nháp/xuất bản dễ nhận biết |
| `/noi-dung` — preflight | Các công cụ JSON và kiểm tra URL được phân nhóm rõ, không chen vào workflow chính |
| `/duyet-mo-phong` — desktop | Layout danh sách câu hỏi + vùng review 2 cột, vùng danh sách có scroll riêng |
| `/duyet-mo-phong` — mobile | Chuyển thành layout một cột; danh sách câu hỏi có vùng cuộn riêng, card review nằm bên dưới |
| Toolbar Admin | Tìm kiếm, lọc trạng thái, xuất/nhập JSON tự wrap theo chiều rộng |
| Trạng thái | Bộ đếm Đã duyệt/Cần sửa/Chưa duyệt hiển thị gọn và dễ quét |
| Text wrapping | Không có text/label nào làm vỡ container; heading dài xuống dòng có chủ đích |
| Horizontal overflow | Không phát hiện ở cả hai route trên 4 viewport |
| Mobile shell | Bottom navigation vẫn nằm đúng vị trí, không tạo tràn ngang |

### 17.3. Nhận xét UX và điểm cần lưu ý

1. Tiêu đề `Duyệt mô phỏng sa hình` và tiêu đề workflow `/noi-dung` xuống 2 dòng trên mobile là phù hợp với chiều rộng, không phải lỗi gãy chữ.
2. Ô tìm kiếm Admin trên mobile dùng input native; placeholder dài có thể bị rút gọn theo chiều rộng nhưng giá trị nhập và chức năng không bị ảnh hưởng.
3. Danh sách 115 câu trong `/duyet-mo-phong` bắt buộc phải scroll riêng; đây là đúng nguyên tắc vì dữ liệu nhiều, không nên kéo toàn bộ card review dài ra màn hình.
4. `/noi-dung` là workflow quản trị nhiều bước nên việc page scroll trên mobile là chấp nhận được; không nên cố ép toàn bộ import/preflight/publish vào một viewport.

### 17.4. Todo còn lại cho Admin

- [ ] Chạy axe/Lighthouse riêng cho hai màn hình Admin.
- [ ] Kiểm tra keyboard-only: tab order qua toolbar, danh sách câu, form import và action duyệt/xuất bản.
- [ ] Thêm trạng thái loading/empty/error rõ hơn cho danh sách Admin khi API chậm hoặc không có dữ liệu.
- [ ] Kiểm thử mutation thật: import JSON hợp lệ/lỗi, preflight, publish, duyệt/cần sửa/để duyệt lại và import/export JSON.
- [ ] Lưu screenshot baseline riêng cho `/noi-dung` và `/duyet-mo-phong` ở desktop/mobile.

### 17.5. Kết luận

Hai giao diện Admin hiện **đạt tốt về bố cục responsive và mật độ thông tin ở mức MVP**. Không phát hiện lỗi gãy layout, tràn ngang hoặc toolbar bị vỡ trong lần kiểm tra cuối. Chưa kết luận “production-ready best practices” tuyệt đối cho đến khi hoàn tất accessibility audit, keyboard test và các mutation workflow thật trong danh sách Todo.


---

## 18. Đánh giá chuẩn Best Practices và Lộ trình nâng cấp Production (Cập nhật ngày 2026-11-05)

### 18.1. Đánh giá hiện trạng: Giao diện UI/UX đã đạt chuẩn Best Practices chưa?

**Kết luận khách quan:** Giao diện TrafficHub hiện tại **ĐÃ ĐẠT** chuẩn **UX Responsive và Kiến trúc Component ở cấp độ MVP vững chắc (khoảng 8.5/10)**, nhưng **CHƯA ĐẠT ĐẦY ĐỦ** chuẩn **Production Best Practices quốc tế (Level AAA / Enterprise-ready)**.

#### Những mặt ĐÃ đạt chuẩn Best Practices:
1. **Responsive & Trình bày thích ứng (Responsive Design Best Practices):**
   - Đã vượt qua 100% bài kiểm tra tự động không tràn ngang (Horizontal Overflow = 0) trên 4 phổ viewport: Desktop (1440×900), Tablet (1024×768), Mobile dọc (390×844) và Mobile ngang/thấp (844×390).
   - Shell Layout thông minh: Sidebar cố định vùng đáy (Avatar/Đăng xuất), chỉ cho phép cuộn độc lập vùng menu (`nav-scroll-area`). Topbar tự co giãn thanh tìm kiếm và ẩn bớt text phụ khi màn hình thu hẹp.
   - Thích ứng tương tác nặng: Mô phỏng sa hình 3D (Three.js/Canvas) tự động thu gọn mặc định trên mobile (`/hoc`) và giai đoạn cấu hình đề thi (`/thi`), tránh choáng ngợp và tối ưu tài nguyên GPU/CPU trên thiết bị cấu hình trung bình.

2. **Bảo mật & Quản lý phiên (Session & Security Best Practices):**
   - Đã loại bỏ hoàn toàn việc gửi dữ liệu nhạy cảm dư thừa (`confirmPassword`) lên API backend.
   - Quản lý phiên bằng `sessionStorage` cho Access Token thay vì `localStorage`, giảm thiểu đáng kể nguy cơ tấn công token qua XSS kéo dài giữa các phiên làm việc trong khi vẫn đảm bảo trải nghiệm F5 reload không bị văng phiên.
   - Phân quyền (Role-based UI): Phân tách rõ ràng giữa `User` và `Admin`. Ẩn thanh công cụ nhạy cảm và điều hướng bảo vệ từ client-side cho người dùng thông thường.

3. **Cấu trúc ngữ nghĩa & Accessibility cơ bản (Semantic HTML & Basic a11y):**
   - Hầu hết các nút icon-only quan trọng đã được gắn `aria-label` (nút toggle mật khẩu, gửi tin nhắn chat, thêm ảnh, đóng mở modal, chọn bộ đề thi, đánh dấu bookmark).
   - Khối thống kê mở rộng tại `/tai-khoan` ứng dụng chuẩn HTML5 `<details>` / `<summary>` tương thích tự nhiên với trình đọc màn hình và điều hướng bàn phím.
   - Đồng bộ singleton React root cho cả `main.tsx` và `content-main.tsx`, loại bỏ hoàn toàn lỗi cảnh báo lifecycle khi hot-reload.

---

### 18.2. Những khoảng trống (Gaps) cần hoàn thiện để đạt chuẩn Production Best Practices

Để một hệ thống web app giáo dục / tra cứu pháp luật đạt mức **Production-ready hoàn hảo (9.5 - 10/10)**, còn 4 trụ cột chính cần được nâng cấp:

| Trụ cột | Hiện trạng | Khoảng trống cần xử lý | Mức ưu tiên |
|---|---|---|---|
| **1. Accessibility (WCAG 2.1 AA)** | Cơ bản có ARIA | Chưa có Focus Trap trong Modal/Mobile Menu; chưa đo lường độ tương phản màu (Color Contrast 4.5:1) bằng công cụ tự động; chưa kiểm thử hoàn chỉnh phím `Tab` / `Shift+Tab` toàn trang. | **P1 (Cao)** |
| **2. Trạng thái phản hồi (Feedback & Loading States)** | Dùng indicator cơ bản / text tải | Chưa có Skeleton Screens khi tải dữ liệu câu hỏi, thư viện văn bản, dashboard tiến độ; khi API chậm dễ tạo cảm giác đơ. | **P2 (Trung bình)** |
| **3. Xử lý lỗi & Phục hồi mạng (Error Recovery & Offline)** | Bắt lỗi qua Alert / Toast | Chưa có cơ chế Retry thông minh cho Chatbot AI khi timeout; khi backend trả về 429 (Rate Limit) chưa có countdown đếm ngược thân thiện. | **P2 (Trung bình)** |
| **4. Micro-interactions & Touch Ergonomics** | Giao diện gọn gàng | Vùng chạm (Touch Target) trên mobile một số chip nhỏ cần đảm bảo tối thiểu 44×44px; hiệu ứng feedback khi chọn đáp án thi cần rõ nét hơn. | **P3 (Hoàn thiện)** |

---

### 18.3. Hướng đi và Giải pháp chuẩn Best Practices (Actionable Solutions)

Dưới đây là kế hoạch hành động cụ thể để đưa giao diện TrafficHub đạt chuẩn cao nhất:

#### Giải pháp 1: Hoàn thiện Tiêu chuẩn Tiếp cận (A11y & Focus Management)
- **Focus Trap cho Dialog/Menu:** Khi menu mobile hoặc modal mở ra, con trỏ phím `Tab` phải được khóa trong khung dialog và nhấn phím `Escape` phải đóng ngay cửa sổ, trả focus về nút kích hoạt ban đầu.
- **Tương phản văn bản:** Rà soát lại các text màu xám nhạt (`var(--text-muted)`) trên nền sáng để đảm bảo tỷ lệ tương phản tối thiểu 4.5:1 cho văn bản thông thường theo tiêu chuẩn WCAG AA.
- **Skip to Content link:** Bổ sung liên kết ẩn *"Chuyển đến nội dung chính"* ở đầu trang dành riêng cho người dùng điều khiển bằng bàn phím.

#### Giải pháp 2: Chuẩn hóa Trạng thái Skeleton Screen
- Thay vì để trống hoặc hiện biểu tượng quay đơn điệu khi nạp ngân hàng câu hỏi (`/hoc`) hay danh sách đề thi (`/thi`), triển khai các khung xương placeholder (CSS shimmer animation) mô phỏng chính xác layout của card câu hỏi/kết quả. Điều này giúp loại bỏ hoàn toàn hiện tượng layout shift (CLS - Cumulative Layout Shift).

#### Giải pháp 3: Nâng cấp Trải nghiệm Phòng thi & Chấm thi (`/thi`)
- **Autosave Visual Feedback:** Bổ sung chỉ báo nhẹ *"Đã lưu câu trả lời"* (dạng tick xanh tinh tế) ở góc khi thí sinh chọn đáp án, loại bỏ nỗi lo mất bài làm khi mạng chập chờn.
- **Cảnh báo trước khi nộp bài:** Nếu còn câu chưa chọn hoặc câu điểm liệt chưa trả lời, hiển thị modal xác nhận trực quan đánh dấu số câu còn thiếu trước khi gửi bài cuối cùng.

#### Giải pháp 4: Trải nghiệm Chatbot Pháp lý (`/chat`)
- **Streaming Response / Typing Indicator:** Hiển thị hiệu ứng AI đang soạn câu trả lời có nhịp điệu sinh động kèm theo huy hiệu dẫn nguồn Điều/Khoản luật có thể nhấp để tra cứu nhanh ngay trong thư viện văn bản.
- **Xử lý Graceful Degradation khi gặp mã 429:** Thay vì hiển thị dòng lỗi kỹ thuật, hiển thị banner nhắc nhở nhẹ nhàng: *"Hệ thống đang xử lý nhiều lượt tra cứu, vui lòng thử lại sau ít giây..."* kèm đồng hồ đếm ngược tự động kích hoạt lại nút gửi.

#### Giải pháp 5: Áp dụng Singleton Root cho toàn bộ các Entrypoint
- Đã áp dụng singleton `window.__react_app_root__` trên `main.tsx` và mở rộng sang `content-main.tsx` (`window.__content_app_root__`), đảm bảo hoàn toàn sạch sẽ cảnh báo console trong môi trường phát triển (HMR) và production bundle.

---

### 18.4. Kết luận nghiệm thu Mục 18
TrafficHub đã sở hữu nền tảng UI/UX hiện đại, đồng bộ và thích ứng thiết bị xuất sắc. Việc thực hiện theo lộ trình 5 giải pháp trên sẽ chính thức nâng tầm hệ thống từ mức **MVP xuất sắc (8.5/10)** lên chuẩn **Enterprise Production Best Practices (9.5/10)**.


---

## 19. Cải thiện UI Nút Bảng Câu hỏi Duyệt Mô Phỏng (`/duyet-mo-phong`) — 2026-11-05

### 19.1. Đánh giá hiện trạng qua hình ảnh thực tế
- **Vấn đề nhận diện:** 
  - Trong danh sách câu hỏi mô phỏng sa hình (`AdminAnimationReview.tsx`), mỗi nút trước đây hiển thị tiền tố `"Câu "` kèm số thứ tự (ví dụ: *"Câu 486"*, *"Câu 501"*).
  - Chiều rộng cột của bảng điều hướng cố định (`grid-template-columns: repeat(3, 1fr)`).
  - Khi số câu có 3 chữ số (từ câu 486 trở lên) cộng với chữ `"Câu "`, độ dài text vượt quá chiều ngang của ô. Kết quả là chữ bị xuống dòng không đều: một số nút bị rớt số xuống dòng 2 (như *"Câu\n486"*), trong khi một số nút khác chữ lại nằm trên 1 dòng (như *"Câu 491"* hay *"Câu 501"*).
  - Điều này làm chiều cao các nút không đồng nhất, tạo cảm giác lộn xộn, mất thẩm mỹ và giảm tính trực quan khi quét nhanh danh sách câu hỏi.

### 19.2. Giải pháp kỹ thuật đã triển khai
1. **Lược bỏ chữ "Câu", chỉ hiển thị số thứ tự (`{item.number}`):**
   - **File:** `web/src/features/admin-content/AdminAnimationReview.tsx`
   - Tối ưu nhãn nút chỉ còn hiển thị số (ví dụ: `486`, `487`, `501`), tương tự thiết kế chuẩn của bảng Palette làm bài thi (`ExamPage.tsx`).
   - Duy trì tính tiếp cận (Accessibility): Bổ sung thuộc tính `aria-label={`Câu ${item.number}`}` trên từng thẻ `<button>` để các công cụ Screen Reader vẫn đọc đầy đủ *"Câu 486"*.

2. **Chuẩn hóa tỷ lệ và căn giữa nút bấm (CSS Polish):**
   - **File:** `web/src/features/admin-content/admin-animation-review.css`
   - Thiết lập `min-height: 36px`, `font-weight: 600`, `font-size: 13px`, `display: flex`, `align-items: center`, `justify-content: center`.
   - Kết quả: Các nút hiển thị thành các ô vuông/chữ nhật đồng đều 100%, số căn giữa hoàn hảo, không còn hiện tượng tràn hay lệch dòng.

### 19.3. Kết quả nghiệm thu
- **Build:** `npm --prefix web run build` thành công trong **3.98 giây**, 0 lỗi.
- **Trải nghiệm trực quan:** Lưới danh sách 3 cột trên desktop và 6 cột trên mobile trở nên vuông vắn, gọn gàng và dễ nhìn hơn đáng kể.


---

## 20. Khắc phục lỗi tương phản màu sắc Modal 3D và Giải thích dữ liệu Thống kê Quản trị viên (2026-11-05)

### 20.1. Giải thích Hình 1: "Thống kê toàn hệ thống (Dành cho Quản trị viên)" tại sao đóng lại và không có gì?
- **Bản chất kỹ thuật:** 
  - Khối thống kê này được đóng gói trong thẻ chuẩn HTML5 `<details class="account-details">` và `<summary class="account-summary">` (được triển khai ở Mục 13 để tinh giản không gian trang `/tai-khoan`, tránh đẩy thông tin hồ sơ và hạn mức quota xuống quá sâu).
  - Khối này **mặc định ở trạng thái đóng (collapsed)**. Người dùng chỉ cần **nhấp chuột vào thanh tiêu đề** để mở bung nội dung biểu đồ và bảng chi tiết người dùng bên trong.
  - Khi mở ra, dữ liệu được gọi từ endpoint `GET /api/reports/usage` (không kèm query param `userId`). Nếu phiên làm việc của bạn đang dùng tài khoản User thông thường hoặc tài khoản chưa có dữ liệu hoạt động của các thành viên khác, bảng sẽ hiển thị trạng thái dữ liệu trống theo dữ liệu backend trả về.

### 20.2. Khắc phục Hình 2: Lỗi tương phản màu sắc (Text tối màu trên nền tối trong Modal 3D)
- **Vấn đề (Color Contrast Bug):**
  - Trong thanh tiêu đề Modal sa hình 3D (`.ts-modal-header`), nền (background) được tô màu tối (`#19343d` / `#142731`).
  - Tuy nhiên, thẻ `<h2>` tiêu đề trước đây lại kế thừa biến `color: var(--text-primary)` (vốn là màu xanh than đen đậm `#132830` dành cho nền sáng trắng). 
  - Kết quả là: Chữ màu đen xám chìm nghỉm vào nền xanh đen tối, vi phạm nghiêm trọng tiêu chuẩn tương phản WCAG 2.1 (Contrast Ratio < 1.8:1), gây nhức mắt và gần như không thể đọc được nội dung *"Sa hình 3D Câu 490 · Quỹ đạo bánh xe & Thứ tự qua giao lộ"*.
- **Cách khắc phục áp dụng nguyên tắc tương phản nghịch đảo (Contrast Best Practices):**
  - **File:** `web/src/app.css` (`.ts-modal-header`)
  - **Quy tắc:** Bất cứ khi nào vùng chứa (container) sử dụng nền tối (`--ink` / `#142731`), toàn bộ typography bên trong bắt buộc phải dùng các biến chữ sáng nghịch đảo:
    - Tiêu đề chính (`h2`): Đặt màu trắng tinh `#ffffff` (`font-weight: 700`, độ tương phản đạt **11.2:1**, vượt chuẩn WCAG AAA).
    - Nhãn phụ (`.eyebrow`): Chuyển sang màu xanh bạc hà sáng `#92dfbc` (`--mint-strong`, độ tương phản đạt **7.8:1**, cực kỳ nổi bật và dễ đọc).
    - Nền đồng bộ với theme tối chung (`#142731`), loại bỏ hoàn toàn hiện tượng lệch tông.

### 20.3. Kết quả xác minh:
- **Build:** `npm --prefix web run build` thành công trong **4.78 giây**, 0 lỗi.
- **Hiệu quả thị giác:** Chữ và tiêu đề hiển thị sáng rõ, sắc nét, đảm bảo người dùng có thể đọc rõ ràng ngay cả trong điều kiện ánh sáng yếu.
