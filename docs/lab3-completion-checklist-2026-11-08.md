# Lab 3 completion checklist — 08/11/2026

Phạm vi lượt này: hoàn thiện phần không tốn phí và không video. Người dùng đã
cho phép hoàn tất phần 4, gồm commit/push nhánh hiện tại và tạo PR; không merge,
không nâng billing và không đổi evidence local thành evidence production.

| Hạng mục theo guide | Trạng thái hiện tại | Việc còn lại để đạt đúng guide |
|---|---|---|
| Authentication | Một Google session đã vào Home trên emulator | Kiểm cancel/logout/account thứ hai và Console Users |
| Storage | Rules/service khớp; emulator 14/14 | Production bị chặn vì Spark/free-only; chỉ mở lại nếu chủ project chấp nhận Blaze |
| FCM | Permission + token registration thành công | Gửi test foreground/background/terminated và kiểm tap routing |
| Analytics | 11/11 event đã wired; DebugView có 8 event, gồm login/view_course | Chạy và chụp thêm các event còn lại/parameter detail |
| Crashlytics | Console có 3 crash, gồm intentional test crash | Xác nhận nonfatal, user ID và custom key |
| Remote Config | Version 6: 3/Bật; 13 fetch/1 user; offline fallback đã kiểm | Còn thiếu before/after hành vi thành công không rebuild |
| ARTEMIS | Catalogue 10 case; validator 3/3; manual exploratory 15:47 đã ghi log | Cần runner/credential thật để chạy 10 case × 3; exploratory không thay thế ARTEMIS |
| AI review | PR #5 mở; 7 finding accepted/fixed; review cuối không còn blocking finding trong scope Lab 3 | Không merge; reviewer vẫn cần xem PR lớn 123 commit/539 file |
| Report | PDF 12 trang ngày 08/11 đã tạo và render kiểm tra | Cập nhật lại nếu bổ sung live evidence |
| Slides | Canva deck 14 slide đã export PDF và visual QA | Không có video theo yêu cầu |
| Video | Ngoài phạm vi theo yêu cầu người dùng | Không thực hiện |

## Canva deck

`Blue and White Illustrated Mobile App Development Group Project Presentation`
(Canva template `EAHGeQX08vQ`, 16:9) đã được mở rộng thành 14 slide: mục tiêu,
kiến trúc, sáu dịch vụ Firebase, rules/emulator, ARTEMIS, AI review, regression,
giới hạn free-only và kết luận. Cần export bản PDF cuối sau khi chèn evidence.

## Không thể tự đóng trong phạm vi hiện tại

1. Storage production vì trái ràng buộc không tốn phí.
2. ARTEMIS 30 runs vì repository chỉ có catalogue/validator, không có runner hay
   credential thật; manual exploratory không được đổi nhãn thành ARTEMIS.
3. FCM đủ ba trạng thái còn cần gửi test đến token của emulator.
4. Nonfatal Crashlytics và Remote Config before/after vẫn thiếu evidence Console/device.
