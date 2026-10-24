# Mở rộng: hỏi đáp bằng hình và học/luyện thi lý thuyết giao thông

**Phân công hiện hành nằm ở task.md và IMPLEMENTATION-PLAN.md.** Nội dung sau tiếp tục mô tả tính năng/luồng; bảng chia việc cũ chỉ tham khảo nếu khác bản hợp nhất mới.

Cập nhật theo yêu cầu người dùng ngày 24/10/2026. Đây là scope mới được bổ sung vào plan; chưa triển khai source hoặc kiểm chứng runtime. Không chuyển các chức năng học môn FLM thành chức năng giao thông.

## 1. Trải nghiệm người dùng đích

App có ba phần liên kết: hỏi đáp luật bằng chữ/ảnh, học ngân hàng câu hỏi lý thuyết, luyện đề/thi thử và xem lại kết quả. Từ một câu trong ngân hàng có thể mở chatbot để hỏi “vì sao đáp án này đúng?”; chatbot phải nhận question ID/version, ảnh và lựa chọn tương ứng, không đoán câu hỏi dựa vào ảnh gần giống.

Nguồn bộ câu hỏi/đáp án cần có xuất xứ, phiên bản và phạm vi hạng bằng. Không tự cố định một số lượng câu hỏi hoặc cấu trúc đề áp dụng cho mọi hạng bằng. Các con số ở UI được lấy từ bank/profile đã import và được kiểm tra, không hard-code từ trí nhớ.

## 2. Chatbot hiểu và giải thích hình giao thông

Các tính năng cần xây:

- Gửi ảnh chụp câu hỏi, biển báo, sa hình, giao lộ và tình huống trong đề lý thuyết; có thể kèm câu hỏi gõ tay.
- Nhận diện chữ trong ảnh, phương án A/B/C/D và các yếu tố nhìn thấy: xe, biển, đèn, vạch đường, hướng di chuyển, vị trí tương đối.
- Người dùng được xem/sửa phần chữ nhận dạng trước khi gửi nếu ảnh mờ hoặc mất ký tự. Ảnh thiếu dữ kiện thì chatbot nêu dữ kiện thiếu và hỏi bổ sung, không tự điền biển/đèn bị che.
- Giải thích ý nghĩa biển báo/vạch kẻ/đèn; phân tích quyền ưu tiên, thứ tự xe đi và hành vi đúng/sai khi có đủ dữ kiện.
- Với câu đã có trong bank: dùng đáp án chuẩn/version của câu đó, giải thích đáp án đúng và vì sao các lựa chọn còn lại sai. Với ảnh ngoài bank: phân tích có điều kiện, không trình bày suy luận như đáp án chính thức của bộ đề.
- Liên kết căn cứ pháp lý đã xác minh và nguồn câu hỏi; chỉ nêu Điều/Khoản/Điểm khi retrieval có căn cứ tương ứng. Không coi mô hình vision là nguồn xác minh hiệu lực luật.
- Hội thoại tiếp nối theo cùng ảnh/câu hỏi, ví dụ “nếu xe này rẽ trái thì sao?”; lưu attachment/question/version context rõ ràng, không gửi toàn bộ lịch sử không giới hạn.
- Trạng thái riêng cho ảnh không đọc được, thiếu dữ kiện, không tìm được căn cứ và provider lỗi.

Tất cả inference dùng API: adapter vision/OCR API cho ảnh, Groq text generation theo plan hiện tại và embedding API. Chỉ chọn model/provider vision sau khi kiểm tra khả năng nhận ảnh của model đang dùng; không mặc định mọi Groq text model đều nhận ảnh. Không chạy OCR/LLM/embedding model local. Tiền xử lý kích thước/định dạng ảnh thông thường không phải inference AI local.

Luồng: client upload → REST kiểm tra file/quyền/quota → lưu attachment private → gRPC vision extraction → tìm câu bank nếu có ID/tương quan đủ rõ → retrieval luật → text API giải thích → lưu answer/citations/context → event/quota như chat chữ. Không cho vision tự tải URL tùy ý trong mạng nội bộ; attachment chỉ được truy cập qua đường do backend kiểm soát.

Giới hạn kích thước/MIME/số ảnh, thời gian lưu và ngân sách API phải cấu hình. Log không chứa ảnh/base64 hay signed URL; chi phí/usage ảnh và text được tách rõ khi provider cung cấp. Không đánh dấu request ảnh thành công khi chỉ có text fallback mà chưa đọc được ảnh.

## 3. Ngân hàng và chế độ học lý thuyết

- Chọn bank/version và hạng bằng/profile tương ứng.
- Danh sách đầy đủ câu hỏi, hiển thị tổng số và tiến độ đã học/chưa học.
- Lọc/tìm theo nội dung, chủ đề, biển báo, sa hình, câu có ảnh, câu quan trọng/điểm liệt nếu bộ dữ liệu có đánh dấu được xác minh.
- Học theo thứ tự, theo chủ đề hoặc chọn một khoảng câu, ví dụ câu 1–50.
- Tạo lượt học với N câu người dùng chọn, ví dụ 10/20/50; kiểm tra số lượng khả dụng thay vì giả định bank luôn đủ.
- Chọn đáp án và nhận đúng/sai, đáp án chuẩn, giải thích và nguồn trong chế độ học.
- Đánh dấu câu muốn ôn; lưu câu làm sai; ôn lại câu sai/chưa làm/đã đánh dấu.
- Tiếp tục lượt học đang dở; lưu tiến độ theo từng tài khoản, bank/version và chủ đề.
- Xem tỷ lệ đúng, số câu đã học, số câu còn lại và nhóm thường sai. Chỉ thống kê từ lượt trả lời thực.
- Mở “hỏi AI về câu này” với ID/version/ảnh/phương án được giữ nguyên.

Nội dung chuẩn gồm question text, ảnh/assets, lựa chọn, correct option IDs, lời giải, chủ đề, hạng/profile, nguồn, version, cờ câu quan trọng khi có. AI có thể giải thích; không dùng output AI làm đáp án chuẩn để chấm người dùng.

## 4. Trộn câu, bộ đề và thi thử

- Chọn bộ đề được biên soạn sẵn theo một bank/version/profile.
- Tạo bộ câu ôn ngẫu nhiên với N câu, phạm vi chủ đề, bao gồm/ưu tiên câu sai hoặc câu chưa học khi người dùng chọn.
- Trộn thứ tự câu hỏi; không lấy trùng câu trong cùng lượt. Nếu pool không đủ thì báo rõ hoặc yêu cầu giảm N.
- Trộn phương án chỉ với câu được đánh dấu có thể trộn. Giữ đáp án bằng option ID và lưu permutation; không trộn câu có lựa chọn tham chiếu “cả A và B”, “tất cả phương án trên”, nhãn gắn với ảnh hoặc thứ tự có ý nghĩa khi chưa có quy tắc chuyển đổi an toàn.
- Phân biệt đề ôn tùy chỉnh và đề mô phỏng thi: đề thi dùng profile cấu trúc đã xác minh (phân bổ chủ đề/số câu/thời gian/điều kiện đạt/câu điểm liệt nếu có), không lấy ngẫu nhiên N câu rồi gọi là đề chuẩn.
- Làm bài, chuyển câu, đánh dấu xem lại, hiển thị câu đã/chưa trả lời, lưu nháp.
- Thi thử có đồng hồ server, thời điểm hết hạn bền vững; reload/reconnect không được đặt lại thời gian. Chế độ học có thể tiếp tục; bài thi quá hạn xử lý theo policy.
- Nộp bài hoặc hết giờ thì server chấm theo đáp án chuẩn của snapshot. Submit idempotent; không gửi đáp án đúng hoặc giải thích xuống client trước khi kết thúc bài thi.
- Kết quả gồm số đúng/sai/bỏ trống, điểm, thời gian và đạt/chưa đạt theo profile. Nếu có luật điểm liệt thì giải thích nguyên nhân trượt bằng dữ liệu profile, không hard-code một luật cho mọi hạng.
- Xem lại từng câu và giải thích sau nộp; đưa câu sai vào danh sách ôn tập.
- Lịch sử các lượt học/thi, tiến bộ theo thời gian và làm lại đề. Lượt đã chấm giữ nguyên snapshot dù bank đổi version.

Chatbot hỗ trợ giải thích ngay trong chế độ học. Trong thi thử, khóa gợi ý/đáp án AI theo policy đến khi nộp bài; các endpoint giải thích cũng kiểm tra trạng thái bài thi, không chỉ ẩn nút trên UI.

## 5. Quản trị dữ liệu học/thi

- Import question bank bằng file chuẩn và assets ảnh; kiểm tra schema, duplicate ID, đúng mapping phương án/đáp án, file ảnh tồn tại và nguồn/version.
- Import draft → kiểm tra → publish version; preview lỗi trước khi publish. Không tự publish đáp án do OCR/AI suy luận.
- Quản lý metadata bank, chủ đề, phạm vi hạng bằng và profile đề; tạo/sửa/publish bộ đề dựng sẵn.
- Ngừng dùng phiên bản/câu lỗi cho lượt mới; không làm thay đổi lịch sử đã chấm. Cache phải gắn bank/version.
- Nếu nguồn chưa có hoặc chưa xác minh, ghi rõ là dữ liệu thiếu; fixture dùng test được đánh dấu, không hiển thị như ngân hàng đề chính thức.

## 6. Thiết kế backend đề xuất

Tiếp tục giữ layer/controller mỏng và API-only AI. Services mới: IImageChatService, IQuestionBankService, IPracticeService, IExamService, ILearningProgressService. Chấm điểm và randomization do code nghiệp vụ quyết định, không gọi LLM để quyết định pass/fail.

API đề xuất, chưa triển khai:

| API | Vai trò |
| --- | --- |
| POST /api/chats/{sessionId}/attachments | Upload ảnh private |
| POST /api/chats/{sessionId}/messages | Thêm attachment IDs hoặc question ID/version vào request hiện có |
| GET /api/question-banks | Danh sách bank/version/profile |
| GET /api/question-banks/{id}/questions | Lọc/tìm/phân trang câu hỏi |
| GET /api/questions/{id} | Chi tiết theo chế độ/quyền; không lộ answer khi thi |
| POST /api/practice-attempts | Tạo lượt học theo chủ đề/range/N/random/wrong/unseen |
| PUT /api/practice-attempts/{id}/answers/{questionId} | Lưu lựa chọn và phản hồi chế độ học |
| GET /api/exam-templates | Danh sách bộ đề sẵn/profile |
| POST /api/exam-attempts | Tạo bài thi từ template hoặc profile |
| PUT /api/exam-attempts/{id}/answers/{questionId} | Lưu đáp án thi, không trả đáp án chuẩn |
| POST /api/exam-attempts/{id}/submit | Chấm bài một lần, kể cả retry |
| GET /api/learning/progress | Tiến độ/chủ đề/câu sai/lịch sử |
| PUT /api/questions/{id}/bookmark | Đánh dấu câu để ôn |
| POST /api/admin/question-banks/import | Import draft và kiểm tra dữ liệu |
| POST /api/admin/question-banks/{id}/publish | Publish phiên bản đã kiểm tra |

GET chi tiết/lịch sử lượt học và thi cần ownership, pagination; bổ sung endpoint tương ứng khi chốt OpenAPI. ID luôn đi cùng version hoặc trỏ đến record bất biến; không chấm theo version “mới nhất” khi người dùng đã bắt đầu bản cũ.

### Ràng buộc dữ liệu 7 bảng

AGENTS.md hiện chỉ cho 7 bảng nghiệp vụ RAG. Ngân hàng câu hỏi/lượt thi/đáp án/bookmark là dữ liệu mới, không nên nhét vào ChatMessages hoặc thêm bảng mà coi như đã được giảng viên duyệt.

Thiết kế để review: giữ nguyên 7 bảng core; question bank/đề/version/assets là gói JSON bất biến có manifest và hash; dữ liệu người học cần persistence riêng. Đề xuất mô hình học tập gồm QuestionBanks, Questions (options/assets có cấu trúc), ExamTemplates, LearningAttempts, AttemptAnswers và QuestionBookmarks trong schema/module mở rộng. Có thể derive tiến độ từ attempts/answers, không cần thêm bảng report. Attachment chat có metadata/quyền/retention riêng, không lưu base64 vào ChatMessages.

Đây là đề xuất dữ liệu cho scope mới, chưa chốt schema SQL hoặc tạo migration. Bảo cần đưa thiết kế này vào review cùng ràng buộc 7 bảng trước khi triển khai persistence; các phần API contract, import/parser/vision/UI có thể thiết kế song song. Không giả định giới hạn cũ đã tự động được bỏ chỉ vì bổ sung chức năng.

## 7. Chia phần mở rộng cho 5 người

| Người | Phần việc mở rộng | Bàn giao chính |
| --- | --- | --- |
| Bảo | Learning schema đề xuất, attempt/answer/bookmark persistence, progress/history, server grading transaction | Migration proposal, repositories/interfaces, submit idempotency, truy vấn progress |
| Khôi | Vision/OCR API, structured image understanding, chatbot giải thích câu/ảnh dựa đáp án chuẩn và legal RAG | Proto/API adapters, image/context contract, test thiếu dữ kiện và citations |
| Khánh | Random selection không trùng, option shuffle an toàn, template/profile engine, deadline/scoring use case cùng Bảo, background expiry | Practice/exam services, test distribution/seed/timeout, Worker handlers |
| Vương | Tích hợp REST/chat ảnh, attachment access, routing/config/telemetry; hợp nhất OpenAPI và kịch bản demo client | API tích hợp, config, demo upload/học/thi; UI mới nếu nhóm chốt client cụ thể |
| Phúc | Thu thập/import bank và ảnh, nguồn/version/chủ đề/profile, dữ liệu lời giải, Admin preview/publish, đối chiếu nguồn | Import pipeline, manifest thật, schema validation, bộ dữ liệu đủ điều kiện publish |

Đây là công việc tăng thêm, không thay thế các task core đã chia. Tránh dồn toàn bộ vào Khôi: scoring/randomization không phải AI, import nội dung do Phúc, persistence do Bảo. Vương không mặc định chịu toàn bộ frontend khi scope/client UI chưa được chốt; hiện có thể nghiệm thu API bằng Swagger/Postman trước.

## 8. Mốc nghiệm thu và test chính

1. Contract bank/question/option/version/profile/attempt cùng evidence nguồn. Cả nhóm có thể thiết kế song song sau khi chốt bản đầu.
2. Lát cắt học: import bank thật → list theo N/chủ đề → chọn đáp án → giải thích → lưu tiến độ → tiếp tục phiên.
3. Lát cắt thi: tạo đề → shuffle không trùng → timer → nộp/chấm server → lịch sử/ôn sai. Kiểm tra đổi version không đổi kết quả cũ.
4. Lát cắt ảnh: upload ảnh câu thật → đọc nội dung/sa hình → giải thích grounded → follow-up theo cùng context. Không hứa mọi ảnh đều nhận dạng đúng; test ảnh rõ/mờ/cắt mất biển, và từ chối suy đoán thiếu dữ kiện.
5. Kiểm tra ownership/answer leakage, reload timer, submit đồng thời/retry, không đủ pool, shuffle phương án tham chiếu, bank lỗi chưa publish, provider timeout, quota usage ảnh/text.

Plan này không ấn định tổng số câu ngân hàng, thời gian thi hay điểm đạt cụ thể khi chưa chọn và xác minh nguồn/profile; không tuyên bố câu hỏi do AI tạo là đề thi chính thức.
