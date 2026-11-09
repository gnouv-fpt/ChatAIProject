# Bổ sung phạm vi cloud theo yêu cầu người dùng 21–22/10/2026

Yêu cầu v7 cũ đặt bảng điểm local-only. Người dùng sau đó yêu cầu Google Sign-In, profile/bảng điểm thuộc đúng tài khoản trên Firestore và giữ dữ liệu khi mở lại. Phạm vi mới áp dụng cho phiên authenticated production: profile và điểm đã xác nhận lưu Firestore theo UID. Dữ liệu legacy local không tự import vào tài khoản đầu tiên; ảnh không được đưa vào Firestore/RAG. Luồng local-only theo persona cũ chưa có lựa chọn riêng trong production mới và không được đánh dấu hoàn thành.

Login/Account UI mới cần bổ sung vào Figma, handoff và privacy copy. Không thay đổi các file persona/Figma đang dirty của lượt trước để ghi nhận chúng là đã nghiệm thu; trạng thái chênh lệch nằm trong design-traceability.md.

Lab 3/Final tiếp tục giữ các tiêu chí riêng: Final không có custom server/Cloud Storage; luồng RAG FastAPI hiện tại chưa được chuyển sang Firebase AI Logic. Đây vẫn là gap mở, không coi kết nối Firestore là đã đạt Final.
