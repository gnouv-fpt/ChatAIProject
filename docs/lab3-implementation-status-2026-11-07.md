# Lab 3 implementation status — 07/11/2026

Mục kiến trúc số 2 được bỏ theo yêu cầu. Phạm vi còn lại đã được hiện thực local:

- Auth, Storage PDF/upload, Messaging, Analytics, Crashlytics và Remote Config.
- Firestore/Storage default-deny rules với owner/schema validation và emulator tests.
- ARTEMIS catalogue 10 ca cùng kiểm tra evidence; device run 3× vẫn là bước ngoài máy.
- AI review có sáu findings, quyết định và các fix được chấp nhận.

Chưa được tuyên bố hoàn tất nếu thiếu evidence bên ngoài: Firebase Console,
DebugView/Crashlytics/FCM production, Remote Config publish trước/sau, 30 ARTEMIS
runs, exploratory session, PR/push, report PDF, slide PDF và video. Không có
deploy/publish/push nào được thực hiện.
