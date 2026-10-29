# Hướng dẫn đăng nhập Google trên Android cho cả nhóm

Tài liệu này giúp mọi thành viên chạy app Flutter (`flutter_app`) trên emulator hoặc điện thoại và **đăng nhập Google thật** mà không cần tự đăng ký SHA-1 trên Firebase.

Làm theo thứ tự từ mục 2 đến mục 6. Mỗi máy chỉ cần cài một lần.

---

## 1. Vì sao cần làm bước này?

Google chỉ cho app Android đăng nhập khi **chữ ký (SHA-1)** của file APK đã được đăng ký trong project. Chữ ký này đến từ một file gọi là **keystore**.

- Bình thường, mỗi máy tự tạo một keystore debug riêng, nên mỗi máy có SHA-1 khác nhau.
- Máy nào chưa đăng ký SHA-1 thì bấm đăng nhập sẽ báo **"Không thể đăng nhập. Vui lòng thử lại."**
- Muốn đăng ký một SHA-1 phải sửa ở **2 nơi** (Firebase và Google Cloud) và cần quyền quản trị project.

**Cách nhóm làm:** cả nhóm dùng chung **một keystore debug** đã được đăng ký sẵn. Ai có file này thì build ra APK cùng chữ ký và đăng nhập được ngay.

SHA-1 của keystore chung (đã đăng ký ở cả Firebase và Google Cloud):

```text
14:E0:41:99:B0:C4:39:99:C6:35:CD:A8:F5:B3:68:B0:8C:AB:E5:EA
```

---

## 2. Chuẩn bị

| Cần có | Ghi chú |
|---|---|
| Android Studio | Đã cài plugin **Flutter** (File → Settings → Plugins → Marketplace → "Flutter" → Install, rồi Restart IDE) |
| Flutter SDK | Đã chạy `flutter doctor` không còn lỗi Android |
| Code mới nhất | Pull nhánh chung `PRM-Lab3-integration` (hoặc `prm-bao-dev` khi chưa merge) |
| File `flm-team-debug.keystore` | Nhận từ **Bảo** qua kênh riêng của nhóm (Zalo nhóm / Drive giới hạn quyền) |
| Một tài khoản Google để test | Nên dùng tài khoản phụ, không dùng tài khoản chính |

> ⚠️ **Không commit, không đăng công khai file keystore.** Repo đã cấu hình để Git tự bỏ qua file này, nhưng đừng gửi lên nhóm chat công khai hay link Drive ai cũng mở được.

---

## 3. Cài keystore chung (một lần mỗi máy)

1. **Đặt file keystore** vào đúng vị trí:

   ```text
   flutter_app/android/flm-team-debug.keystore
   ```

2. **Tạo file `key.properties`**: trong thư mục `flutter_app/android`, sao chép file `key.properties.example` và đổi tên bản sao thành `key.properties`. **Giữ nguyên nội dung**, gồm:

   ```properties
   debugStoreFile=flm-team-debug.keystore
   debugStorePassword=android
   debugKeyAlias=androiddebugkey
   debugKeyPassword=android
   ```

3. Kết quả trong thư mục `flutter_app/android` phải có đủ:

   ```text
   flutter_app/android/
   ├── app/
   ├── flm-team-debug.keystore   ← file nhận từ Bảo
   ├── key.properties            ← bản sao của key.properties.example
   └── key.properties.example
   ```

Hai file `flm-team-debug.keystore` và `key.properties` **sẽ không hiện trong `git status`**. Đó là đúng, vì chúng đã được ignore.

---

## 4. Nếu đường dẫn project có dấu tiếng Việt

Ví dụ project nằm ở `D:\kỳ 8\LAB3_PRM393`. Gradle (công cụ build Android) **không chạy được** với đường dẫn có ký tự như "ỳ" và sẽ báo:

```text
Your project path contains non-ASCII characters.
```

**Cách xử lý:** tạo một ổ đĩa ảo trỏ vào thư mục project. Mở PowerShell hoặc Command Prompt và chạy (đổi đường dẫn cho đúng máy bạn):

```bash
subst P: "D:\kỳ 8\LAB3_PRM393"
```

Sau đó trong Android Studio chọn **File → Open** và mở `P:\flutter_app`. Không mở thư mục gốc `D:\kỳ 8\...`.

- Ổ `P:` sẽ **mất khi khởi động lại máy**. Mỗi lần bật máy, chạy lại lệnh trên trước khi mở Android Studio.
- Nếu đường dẫn project không có dấu (ví dụ `D:\PRM393\LAB3_PRM393`) thì bỏ qua mục này.

---

## 5. Kiểm tra đã dùng đúng keystore chưa

Mở Terminal trong Android Studio (hoặc PowerShell), chạy:

```bash
cd P:\flutter_app\android
.\gradlew signingReport
```

Tìm mục `Variant: debug`. Kết quả **đúng** trông như sau:

```text
> Variant: debug
  Config: debug
  Store: P:\flutter_app\android\flm-team-debug.keystore
  Alias: androiddebugkey
  SHA1: 14:E0:41:99:B0:C4:39:99:C6:35:CD:A8:F5:B3:68:B0:8C:AB:E5:EA
```

Nếu dòng `Store` lại là `C:\Users\<tên>\.android\debug.keystore`, nghĩa là build **chưa dùng keystore chung**. Xem lại mục 3: thường do thiếu `key.properties` hoặc đặt sai chỗ.

---

## 6. Chạy app và đăng nhập

### 6.1. Thêm tài khoản Google vào emulator (một lần)

Emulator mới tạo **chưa có tài khoản Google nào**. Thiếu bước này, bấm đăng nhập sẽ báo *"Đăng nhập đã bị hủy…"* dù bạn không bấm huỷ.

1. Bật emulator (Android Studio → **Device Manager** → bấm ▶ cạnh máy ảo). Nên dùng máy ảo có **Google Play**.
2. Trên emulator mở **Settings → Passwords, passkeys & accounts → Add account → Google**.
3. Đăng nhập tài khoản Google test của bạn.

Nếu dùng điện thoại thật đã có tài khoản Google thì bỏ qua bước này.

### 6.2. Chạy app

1. Ở thanh công cụ trên cùng của Android Studio, chọn thiết bị là **emulator / điện thoại**, **không chọn** `Windows (desktop)` hay `Chrome`.
2. Chọn cấu hình `main.dart`, bấm nút **Run ▶** màu xanh.
3. Lần chạy đầu mất khoảng 2–10 phút vì Gradle tải thư viện. Các lần sau nhanh hơn nhiều.

### 6.3. Đăng nhập

1. App mở ra màn **"Đăng nhập để tiếp tục"**. Bấm **Đăng nhập với Google**.
2. Chọn tài khoản trong bảng **Choose an account**.
3. **Lần đầu** mỗi tài khoản, Google hỏi *"Allow Google to sign you in to Cố vấn học tập FLM"*. Bấm **Agree and share**.
4. Vào được **Trang chủ** là thành công.

Dữ liệu (hồ sơ, bảng điểm) được lưu trên Firestore **theo từng tài khoản**. Tài khoản này không thấy dữ liệu của tài khoản kia.

---

## 7. Gặp lỗi thì làm gì?

| App báo / hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| "Đăng nhập đã bị hủy. Nếu máy chưa có tài khoản Google…" | Bạn bấm Back ở bảng chọn tài khoản, **hoặc** máy chưa có tài khoản Google | Làm mục 6.1 rồi thử lại |
| "Không thể đăng nhập. Vui lòng thử lại." | APK chưa ký bằng keystore chung, nên SHA-1 chưa được đăng ký | Kiểm tra mục 5. Nếu `Store` sai, làm lại mục 3 rồi Run lại |
| "Mất kết nối. Kiểm tra mạng rồi thử lại." | Máy/emulator không có Internet | Bật Wi-Fi/tắt chế độ máy bay, bấm đăng nhập lại |
| "Không thể đăng nhập Google. Vui lòng thử lại." | Lỗi khác từ Google Play Services | Cập nhật Google Play Services trên máy, khởi động lại emulator |
| Google báo "Access blocked" / "This app is blocked" | OAuth consent screen của project đang ở chế độ **Testing** và email của bạn chưa nằm trong danh sách *Test users* | Nhờ người quản trị project thêm email bạn vào Google Cloud → **OAuth consent screen → Test users** |
| Gradle báo "project path contains non-ASCII characters" | Đường dẫn có dấu | Làm mục 4 |
| Nút Run xám, chỉ có "Add Configuration" | Chưa cài plugin Flutter hoặc mở sai thư mục | Cài plugin Flutter, mở đúng thư mục `flutter_app` |
| Danh sách thiết bị chỉ có Windows/Chrome | Emulator chưa bật | Bật emulator ở Device Manager rồi chọn lại thiết bị |

### Xem log chi tiết

Khi đăng nhập lỗi, app ghi **mã lỗi** vào log (không ghi email hay token). Trong Android Studio mở tab **Logcat**, gõ ô lọc:

```text
AuthService
```

Ví dụ một số dòng log và ý nghĩa:

| Log | Ý nghĩa |
|---|---|
| `Google sign-in failed: canceled` | Người dùng huỷ, hoặc máy chưa có tài khoản Google |
| `Firebase sign-in failed: network-request-failed` | Không có mạng |
| `Firebase sign-in failed: unknown` + `Requests from this Android client application … are blocked` | SHA-1 của máy chưa được đăng ký trong Google Cloud (chưa dùng keystore chung) |

Gửi ảnh chụp dòng log này cho Bảo nếu vẫn không đăng nhập được.

---

## 8. Câu hỏi thường gặp

**Không có file keystore chung thì có chạy app được không?**
Có. Khi thiếu `key.properties`, build tự dùng keystore riêng của máy. App vẫn chạy, nhưng **đăng nhập Google sẽ lỗi** cho tới khi SHA-1 máy đó được đăng ký (xem mục 9).

**Keystore này có dùng để phát hành app lên Play Store được không?**
Không. Đây chỉ là khoá **debug** với mật khẩu mặc định `android`, dùng cho phát triển và demo trong nhóm.

**Có thể test đăng nhập mà không cần Android không?**
Có thể chạy bản Web (chọn thiết bị Chrome) để thử nhanh. Tuy nhiên các test case nghiệm thu (TC01, TC12) yêu cầu đăng nhập trên Android với bảng chọn tài khoản thật.

**Đổi sang tài khoản khác thế nào?**
Vào tab **Cài đặt → Đăng xuất**, rồi đăng nhập lại và chọn tài khoản khác trong bảng chọn. Muốn có thêm lựa chọn thì thêm tài khoản vào máy theo mục 6.1.

---

## 9. Dành cho người quản trị project: đăng ký SHA-1 mới

Chỉ cần khi một máy **không dùng** keystore chung, hoặc khi nhóm đổi sang keystore khác. Phải làm **đủ cả 2 nơi**:

1. **Firebase Console** → project `flm-prm323-20261021` → **Project settings** → app Android `com.example.flm_courses` → **Add fingerprint** → dán SHA-1 → Save.
   Sau đó tải lại `google-services.json` và chép đè vào `flutter_app/android/app/google-services.json`.
2. **Google Cloud Console** → **APIs & Services → Credentials** → key **Android key (auto created by Firebase)** → mục **Android restrictions** → **Add** → package `com.example.flm_courses` + SHA-1 → Done → Save.

Thay đổi ở Google Cloud có thể mất vài phút mới có hiệu lực. **Không xoá** các SHA-1 cũ đang được người khác dùng.

Lấy SHA-1 của một keystore bằng lệnh `gradlew signingReport` (mục 5).
