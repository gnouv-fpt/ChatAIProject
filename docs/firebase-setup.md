# Firebase provisioning — 21/10/2026

Google Cloud project ID: `flm-prm323-20261021`.
Project number: `913094498381`.
Display name: FLM Student Assistant PRM323.

Google Cloud creation đã thành công. Bước addFirebase bằng CLI trả 403; Console cho thấy tài khoản chưa chấp nhận Firebase terms lần đầu. Người dùng đã đồng ý chấp nhận terms Firebase, đang hoàn tất wizard. Chưa ghi Firebase activation/auth/Firestore thành công khi chưa có xác nhận API/Console.

Code production: main → FirebaseEntry → AuthGate. Bootstrap dùng các dart define: FIREBASE_API_KEY, FIREBASE_APP_ID (đúng nền tảng), FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_AUTH_DOMAIN (web). Google Android cần SHA-1 và GOOGLE_SERVER_CLIENT_ID (OAuth web client). Chưa đặt config giả vào source. Không có cấu hình thì app hiển thị lỗi có retry, không âm thầm bỏ qua đăng nhập.

Không commit OAuth authorization code, access/refresh token, service-account key. Firebase CLI cache và firebase-debug.log không dùng làm tài liệu nộp công khai.

## Chưa nghiệm thu
- Firebase activation và Android/Web app registration.
- Google provider, SHA-1, authorized domain.
- Firestore edition/schema/rules và test emulator.
- Google account picker thật và đổi tài khoản trên Android.
- Analytics/Crashlytics/FCM/Remote Config console evidence.
