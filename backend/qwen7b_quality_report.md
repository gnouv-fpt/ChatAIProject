# Đánh giá Qwen 2.5 7B local

## Phạm vi kiểm thử

- Model: `qwen2.5:7b` chạy local qua Ollama trên RTX 4050 6 GB.
- Dữ liệu: các chunk tài liệu FLM đã index trong hệ thống RAG.
- Chi phí API: 0đ; dữ liệu không rời khỏi máy.
- Đây là đánh giá thủ công định hướng chất lượng, không phải điểm benchmark chuẩn hóa.

## Kết quả thực tế

1. Câu hỏi so sánh PRO192 và PRM393: khoảng 26,9 giây. Sau khi bổ sung truy hồi môn liên quan, câu trả lời đã lấy đúng nguồn PRO192 và nêu được OOP, class/object, inheritance, `List`/`Set`/`Map`. Vẫn còn suy luận quá mức về Java/Kotlin và lỗi diễn đạt nhỏ.
2. Câu hỏi kiểm chứng phủ định (PRO192 có dạy Flutter/Kotlin không?): khoảng 10,5 giây. Model trả lời đúng rằng tài liệu chỉ chứng minh Java và không có bằng chứng cho Flutter/Kotlin.

## Ước lượng

Điểm chất lượng heuristic hiện tại: **khoảng 70%**. Con số này tổng hợp độ bám nguồn, tính đúng, khả năng nói “không đủ bằng chứng” và độ mượt tiếng Việt trên hai probe đại diện; không nên hiểu là độ chính xác đảm bảo cho mọi câu hỏi.

## Khuyến nghị 0đ

Giữ Qwen 7B local làm fallback mặc định cho riêng tư và không tốn phí. Với câu hỏi so sánh khó, nên tăng chất lượng truy hồi/rerank và cho phép chuyển sang quota miễn phí của một API ngoài khi có sẵn; luôn giữ evidence gate để ngăn bịa thông tin.
