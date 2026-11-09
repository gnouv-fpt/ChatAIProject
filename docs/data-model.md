# Firestore data model — Lab 3 slice

Database ID: flm-app, Enterprise Native, Singapore. Mọi path cá nhân dùng UID lấy từ Firebase Auth; UI không truyền UID tùy ý.

| Collection/document | Fields | Create/read/update/delete | Màn |
|---|---|---|---|
| users/{uid} | role:string=user, createdAt:timestamp | Self create role=user; self get; không sửa role, không list/delete | Dự phòng Final; app hiện chưa tự tạo root doc |
| users/{uid}/private/profile | course_goal, learning_style, study_priority, long_term_goal:string enum; current_semester:int 0..12; career_goal:string <=80; đều tùy chọn | Owner only; validate mọi create/update | S07 và student_context |
| users/{uid}/private/preferences | targetGpa:number 0..10 | Owner only | S05/S07 |
| users/{uid}/transcript/{courseCode}_{semester} | courseCode:string, courseName:string<=250, score:number0..10, credits:int0..30, semester:int0..12, isPassed/inProgress:bool, confidence:number0..1 | Owner only; field allowlist; ID phải khớp môn/kỳ | S01/S02/S03/S05/S06 |

Không lưu ảnh bảng điểm, email hoặc nội dung chat vào Firestore trong slice này. Chat vẫn cache local theo UID. Profile và transcript cloud là nguồn chính trong production; không tự import dữ liệu legacy local vào tài khoản Google mới. Đăng xuất xóa cache local của phiên, giữ dữ liệu cloud của tài khoản.

Ghi bảng điểm là thay thế danh sách đầy đủ bằng atomic batch, tối đa 200 dòng từ client; giữ retake ở kỳ khác, từ chối hai dòng cùng môn/kỳ. Khi có hai thiết bị sửa đồng thời, snapshot lưu sau có thể thay thế thay đổi trước; chưa có conflict resolution. Cloud reads dùng Source.server và timeout; khi offline báo lỗi có retry, không giả thành dữ liệu rỗng.

Final roles/admin/review queue/announcements/cross-role chưa có trong rules hiện tại; các collection đó vẫn bị deny. Không coi model này đã hoàn thành Final.
