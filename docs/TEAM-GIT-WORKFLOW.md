# Đồng bộ nhánh theo C2 mới — 27/10/2026

Nền chung: **PRN-dev**. Đọc [task.md](../task.md), [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md), [AGENTS.md](../AGENTS.md). Docs mới không có nghĩa schema đã code.

## Giữ việc đang làm rồi lấy nền

Kiểm tra status, commit đúng files đang làm trên nhánh cá nhân hoặc stash có chủ đích. Không reset/clean, không git add toàn workspace nếu có file ngoài task/secrets.

~~~powershell
git status --short
git fetch origin
git switch <nhánh-cá-nhân>
git merge origin/PRN-dev
~~~

Thay placeholder bằng nhánh thực tế. Bảo: PRN-BAO-dev; Khôi: PRN-KHOI-dev; Vương: PRN-VUONG-dev; Phúc có code mới trên **PRN_Phúc_ASM**, không mặc định PRN-PHUC-dev là mới nhất. Khánh dùng nhánh PRN đang làm; nếu chưa có thì tạo PRN-KHANH-dev từ origin/PRN-dev sau khi kiểm tra tên chưa tồn tại. Không lấy nhánh FLM làm nền PRN.

Conflict phải xem diff/owner, không chọn toàn bộ ours/theirs. Giữ code đã làm và điều chỉnh theo contract mới.

## Ownership

- Vương: schema/entities/repo contracts/hai DbContext/mappings/migrations, host/solution/Gateway/Compose/web shell.
- Bảo: User nghiệp vụ/query/UI; Phúc: Content/Exam nghiệp vụ/query/UI.
- Khánh: Redis đề custom/engine thi và Kafka notification/Worker.
- Khôi: proto nguồn/Python AI; Vương phối hợp .NET adapter.
- Gửi nhu cầu field/query cho Vương; không tự sinh migration mới/sửa model snapshots. Migration cũ giữ lại để rà lịch sử.
- Chờ schema P0 thì tiếp tục UI/parser/AI/tests độc lập; không chờ tới cuối mới chốt schema.

## PR về PRN-dev

1. Commit nhỏ, stage named paths; ghi task IDs theo bản 27/10.
2. Test module, mô tả contract/config thay đổi và giới hạn chưa kiểm chứng.
3. Push nhánh cá nhân; PR base PRN-dev.
4. Owner tích hợp review diff/contracts/build/tests trước merge; không force-push nền chung.
5. Fetch/merge PRN-dev ở vòng tiếp theo.

Docs được phát hành trước; schema và tính năng qua PR tiếp theo. Pull docs chưa tạo hai SQL DB, auth mới hoặc Redis exam.
