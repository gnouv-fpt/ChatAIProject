# Lab 3 implementation status — 07/11/2026

Mục kiến trúc số 2 được bỏ theo yêu cầu. Phạm vi còn lại đã được hiện thực local:

- Auth, Storage PDF/upload, Messaging, Analytics, Crashlytics và Remote Config.
- Firestore/Storage default-deny rules với owner/schema validation và emulator tests.
- ARTEMIS catalogue 10 ca cùng kiểm tra evidence; device run 3× vẫn là bước ngoài máy.
- AI review có sáu findings, quyết định và các fix được chấp nhận.

Chưa được tuyên bố hoàn tất nếu thiếu evidence bên ngoài: Firebase Console,
DebugView/Crashlytics/FCM production, Remote Config publish trước/sau, 30 ARTEMIS
runs, exploratory session, PR/push, report PDF, slide PDF và video. Log ngày 29/10
cho thấy Firestore Rules và Remote Config từng deploy lên `flm-prm323-20261021`;
Storage deploy thất bại vì bucket chưa được khởi tạo.

Lượt 07/11 sau đó: CLI deploy `firestore:rules` và `remoteconfig` thành công lên
`flm-prm323-20261021`; `remoteconfig:get` sau deploy trả về đúng hai key
`next_course_preview_limit=3`, `enable_pe_tips=true` với mô tả trong template.
`storage` deploy vẫn lỗi `Firebase Storage has not been set up` và cần khởi tạo
bucket từ Console. Browser trong Work đang tắt nên chưa kiểm tra giao diện setup.
Chưa có evidence Google login, Storage upload, FCM, Analytics DebugView,
Crashlytics hay Remote Config before/after trên thiết bị. Không push Git.
