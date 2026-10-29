# Debug keystore chung cho nhóm

Google Sign-In trên Android chỉ chạy khi SHA-1 của keystore ký APK đã được đăng ký ở **hai nơi**: Firebase (Project settings → app Android) và Google Cloud Console (Credentials → *Android key (auto created by Firebase)* → Android restrictions). Mỗi máy tự sinh `debug.keystore` riêng nên SHA-1 khác nhau. Để không phải đăng ký từng máy, cả nhóm dùng chung một keystore debug.

SHA-1 của keystore chung (đã đăng ký ở cả hai nơi):

```text
14:E0:41:99:B0:C4:39:99:C6:35:CD:A8:F5:B3:68:B0:8C:AB:E5:EA
```

## Cài đặt trên máy của bạn (một lần)

1. Nhận file `flm-team-debug.keystore` từ Bảo qua kênh riêng của nhóm. **Không commit, không đăng công khai.**
2. Đặt file vào `flutter_app/android/flm-team-debug.keystore`.
3. Chép `flutter_app/android/key.properties.example` thành `flutter_app/android/key.properties` (giữ nguyên nội dung).
4. Build/chạy như bình thường (`flutter run` hoặc nút Run trong Android Studio).

Kiểm tra: trong `flutter_app/android` chạy `gradlew signingReport`; mục `Variant: debug` phải có `Store: ...flm-team-debug.keystore` và SHA1 như trên.

Cả hai file đều bị `flutter_app/android/.gitignore` loại khỏi Git (`key.properties`, `**/*.keystore`). Không có `key.properties` thì build vẫn chạy nhưng dùng keystore riêng của máy, và Google Sign-In sẽ báo lỗi cho tới khi SHA-1 máy đó được đăng ký.

## Lưu ý

- Đây chỉ là khóa **debug**, mật khẩu mặc định `android`. Không dùng để phát hành lên Play Store.
- Nếu Google Sign-In vẫn báo "Không thể đăng nhập", xem log `[AuthService]` trong Logcat. "Requests from this Android client application … are blocked" nghĩa là SHA-1 chưa có trong Google Cloud.
- Đường dẫn repo có ký tự không phải ASCII (ví dụ `D:\kỳ 8\...`) làm Gradle báo lỗi. Ánh xạ sang ổ ảo rồi mở `P:\flutter_app`:

```bash
subst P: "D:\kỳ 8\LAB3_PRM393"
```
