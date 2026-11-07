# Firebase deploy verification - 07/11/2026

Project được chọn rõ: `flm-prm323-20261021` (`FLM Student Assistant PRM323`).
CLI login: account đang đăng nhập được xác nhận bằng `firebase login:list`.
Firestore database: `projects/flm-prm323-20261021/databases/flm-app`, Enterprise, Firestore Native.

| Lệnh | Kết quả |
|---|---|
| `firebase deploy --only firestore:rules --project flm-prm323-20261021 --config firebase.json --non-interactive` | Exit 0; compile thành công, upload và release `firebase/firestore.rules` |
| `firebase deploy --only remoteconfig --project flm-prm323-20261021 --config firebase.json --non-interactive` | Exit 0; deploy complete |
| `firebase remoteconfig:get --project flm-prm323-20261021 --output tmp/lab3-validation/remoteconfig-after-deploy.json` | Trả về `next_course_preview_limit=3`, `enable_pe_tips=true` và mô tả đúng source template |
| `firebase deploy --only storage --project flm-prm323-20261021 --config firebase.json --non-interactive` | Exit 1: Firebase Storage chưa được setup; CLI yêu cầu vào Console và bấm Get Started |

Firebase Rules emulator trước deploy: 14/14 test pass. Kết quả này kiểm rule local; chưa chứng minh truy cập production. Không deploy Authentication provider, không push Git.

Storage còn cần chọn bucket location và có thể cần billing. Chỉ sau khi bucket được tạo mới deploy `firebase/storage.rules`, kiểm owner/non-owner trên Android và lấy Console evidence. Browser Work hiện bị tắt nên không thể kiểm tra bước setup qua UI trong lượt này.
