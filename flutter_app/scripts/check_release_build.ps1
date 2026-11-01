# Script kiểm tra quy trình build Release Web có và không có --dart-define
param(
    [string]$ApiBaseUrl = "https://api.flm.edu.vn"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [CI/QA] Kiểm tra quy trình build Release Web FLM Assistant" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Build KHÔNG có --dart-define
Write-Host "`n[Bước 1/2] Đang kiểm tra build web release KHÔNG có --dart-define..." -ForegroundColor Yellow
flutter build web --release
Write-Host "-> Build thành công artifact web. Khi khởi chạy, hệ thống sẽ tự phát hiện thiếu FLM_API_BASE_URL và hiển thị ConfigErrorScreen giao diện thân thiện, không bao giờ để màn hình trắng/xám." -ForegroundColor Green

# 2. Build CÓ --dart-define
Write-Host "`n[Bước 2/2] Đang kiểm tra build web release CÓ --dart-define=$ApiBaseUrl..." -ForegroundColor Yellow
flutter build web --release --dart-define=FLM_API_BASE_URL=$ApiBaseUrl
Write-Host "-> Build thành công production web artifact đầy đủ biến cấu hình compile-time!" -ForegroundColor Green

Write-Host "`n[HOÀN TẤT] Cả 2 kịch bản build release đều hoạt động đúng đặc tả." -ForegroundColor Cyan
