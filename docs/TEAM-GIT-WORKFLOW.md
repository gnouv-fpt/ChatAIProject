# PRN-dev là nền tích hợp chung

Cập nhật 24/10/2026. Đã dựng PRN-dev local từ code PRN mới, ghép nhánh Phúc và Khôi vào nền Vương/Bảo, giữ scope 7 bảng và các tài liệu kế hoạch. Đã xử lý DI conflict và đăng ký gRPC lặp. Build .NET: 0 warning/error; EF không có pending model changes. Chưa chạy API/Compose hoặc apply migration.

**Các lệnh dùng origin/PRN-dev dưới đây chỉ áp dụng sau khi người giữ nhánh đã push nền mới.** Tại thời điểm lập hướng dẫn, origin/PRN-dev còn ở initial commit cũ; commit local không tự làm đồng đội nhận code mới.

## 1. Phát hành nền chung

Người giữ nền kiểm tra working tree và commit cần phát hành, sau đó push bình thường khi được nhóm cho phép:

```powershell
git switch PRN-dev
git status --short
git log --oneline origin/PRN-dev..PRN-dev
git push origin PRN-dev
```

Không force-push. Nếu remote có commit mới và push bị từ chối, fetch/kiểm tra/tích hợp thay đổi trước, không ghi đè remote. PRN-main chưa dùng làm nền phát triển ở giai đoạn này.

## 2. Bốn người có nhánh PRN sẵn

Nhánh tương ứng: PRN-BAO-dev, PRN-KHOI-dev, PRN-VUONG-dev, PRN-PHUC-dev. Ví dụ với Phúc:

```powershell
git status --short
git fetch origin
git switch PRN-PHUC-dev
git merge origin/PRN-dev
dotnet build ChatAIWeb.slnx
```

Trước khi switch/merge, giữ công việc đang dở bằng commit chọn đúng file hoặc stash có chủ đích; không reset/clean để bỏ changes. Nếu có commit riêng mới thì giải quyết conflict với owner file chung. Khi đang merge, không chạy migration tự động chỉ để kiểm tra build.

Nền mới chứa lịch sử cả bốn nhánh remote đã khảo sát, nên các nhánh chưa có commit riêng mới có thể fast-forward lên nền. Không mặc định điều này còn đúng nếu đồng đội đã commit thêm ở máy họ.

## 3. Khánh tạo nhánh PRN riêng

Không dùng FastAPI-RAG-Backend-Khanh/akkhanh05-test-groq-api làm branch chứa Worker/Exam PRN. Sau khi nền được push, tạo nhánh mới từ nền chung nếu tên chưa tồn tại:

```powershell
git fetch origin
git switch -c PRN-KHANH-dev origin/PRN-dev
```

Nếu nhánh đã tồn tại ở local/remote, chọn nhánh đó và merge nền thay vì tạo lại. Không tạo từ PRN-main initial/Razor cũ. Các nhánh FLM giữ riêng.

## 4. Quy trình làm việc hằng ngày

1. Fetch và đồng bộ origin/PRN-dev vào nhánh cá nhân trước khi bắt đầu feature mới.
2. Code task IDs trong docs/IMPLEMENTATION-PLAN.md; mỗi commit nhỏ, stage named paths, không git add toàn workspace.
3. Build/test module; ghi contract/schema/config thay đổi và phần chưa kiểm chứng.
4. Push nhánh cá nhân khi sẵn sàng, mở PR **base PRN-dev**, không base main/PRN-main.
5. Owner tích hợp kiểm tra diff/contract/build rồi merge PR; mọi người lấy nền mới ở lượt tiếp theo.

Không sửa trực tiếp nhiều người trên PRN-dev. Migrations/DbContext do Bảo; proto do Khôi; events/Worker host do Khánh; REST Program.cs/Compose/web router do Vương; bank/parser/profile do Phúc. Đổi contract phải thống nhất với consumer và ghi trong PR.

## 5. Tài liệu cần gửi team

- task.md: bảng giao việc chính.
- docs/IMPLEMENTATION-PLAN.md: task IDs, APIs, ownership và nghiệm thu.
- docs/TEAM-GIT-WORKFLOW.md: cách đồng bộ branch và PR.

Sau khi các file được push, gửi link trực tiếp tới chúng trên branch PRN-dev và commit nền được phát hành. Không gửi riêng đường dẫn E: của máy cá nhân. API keys cấp qua môi trường/kênh riêng, không đưa vào Markdown/Git.

Migration RemoveUnnecessaryReportingTables đã nằm trong nền; nó xóa hai bảng ngoài scope. Không chạy API với MigrateOnStartup bật trên DB có dữ liệu cũ trước khi kiểm tra/backup. Build và EF model check không áp dụng migration lên DB.
