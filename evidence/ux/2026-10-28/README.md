# UX evidence — 28/10/2026

Branch: `lab3/vuong-ui-review`, baseline `035a5c7`. Review: `docs/vuong-ui-review-2026-10-28.md`.

| Check | Kết quả | Evidence |
|---|---|---|
| Unit/widget suite (exclude live) | 58 pass | flutter-tests.log |
| Static analysis | No issues found | flutter-analyze.log |
| Android debug build | Success, assembleDebug 31.2s | flutter-build.log |
| Tổng quan S08, text scale 1.3 | 360/412/1280 dp, không RenderFlex exception | curriculum-*-scale130.png |
| Tư vấn học kỳ mobile | 360/412 dp, đúng scope/học kỳ, Back/close | advisor-*.png |

Chạy lại từ `flutter_app/`:

```powershell
flutter analyze
flutter test --exclude-tags live --reporter expanded --dart-define=UX_REVIEW_EVIDENCE=true
flutter build apk --debug
```

APK local: `flutter_app/build/app/outputs/flutter-apk/app-debug.apk` (không commit binary). SDK/Gradle có cảnh báo migration Kotlin/XML version trong log nhưng assembleDebug thành công.

Các ảnh render từ widget Flutter thật với Roboto/MaterialIcons SDK, fixture ghi TEST, API health fake offline, OCR failure fake. Không phải ảnh production, usability study, ARTEMIS, Google/Firebase, OCR/AI backend thật. Có kiểm ảnh bằng mắt; tab và breadcrumb cuộn ngang trên mobile. S08 chưa có frame Figma chính thức để đối chiếu pixel parity.
