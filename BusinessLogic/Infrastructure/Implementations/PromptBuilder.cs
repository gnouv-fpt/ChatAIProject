using System.Text;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Infrastructure.Implementations;

public sealed class PromptBuilder
{
    private const string VietnameseNotFoundAnswer = "Không tìm thấy thông tin liên quan trong tài liệu đã tải lên.";
    private const string EnglishNotFoundAnswer = "No relevant information was found in the uploaded documents.";

    public static string GetNotFoundAnswer(string question)
    {
        return QuestionLanguageDetector.Detect(question) == AnswerLanguage.English
            ? EnglishNotFoundAnswer
            : VietnameseNotFoundAnswer;
    }

    public string Build(string question, IReadOnlyList<RetrievedChunkDto> chunks)
    {
        return QuestionLanguageDetector.Detect(question) == AnswerLanguage.English
            ? BuildEnglish(question, chunks)
            : BuildVietnamese(question, chunks);
    }

    private static string BuildVietnamese(string question, IReadOnlyList<RetrievedChunkDto> chunks)
    {
        var builder = new StringBuilder();
        builder.AppendLine("Bạn là chatbot học tập cho sinh viên Việt Nam.");
        builder.AppendLine("Nhiệm vụ của bạn là trả lời dựa trên ngữ cảnh tài liệu được cung cấp.");
        builder.AppendLine();
        builder.AppendLine("Câu hỏi của sinh viên:");
        builder.AppendLine(question.Trim());
        builder.AppendLine();
        builder.AppendLine("Ngữ cảnh tài liệu:");

        if (chunks.Count == 0)
        {
            builder.AppendLine("Không có chunk tài liệu liên quan.");
        }
        else
        {
            foreach (var (chunk, index) in chunks.Select((chunk, index) => (chunk, index)))
            {
                builder.AppendLine($"[Nguồn {index + 1}] {chunk.OriginalFileName}");
                builder.AppendLine($"Chunk: {chunk.ChunkIndex}");
                if (chunk.PageNumber.HasValue)
                {
                    builder.AppendLine($"Trang: {chunk.PageNumber.Value}");
                }

                if (chunk.SlideNumber.HasValue)
                {
                    builder.AppendLine($"Slide: {chunk.SlideNumber.Value}");
                }

                builder.AppendLine($"Độ tương đồng: {chunk.SimilarityScore:0.######}");
                builder.AppendLine("Nội dung:");
                builder.AppendLine(chunk.Content);
                builder.AppendLine();
            }
        }

        builder.AppendLine("Quy tắc trả lời:");
        builder.AppendLine("- Sinh viên hỏi bằng tiếng Việt nên chỉ trả lời bằng tiếng Việt, rõ ràng và phù hợp bối cảnh học thuật.");
        builder.AppendLine("- Trả lời đầy đủ, không cụt: nêu câu trả lời trực tiếp trước, sau đó giải thích chi tiết, ví dụ hoặc bối cảnh liên quan có trong tài liệu, và kết thúc bằng lưu ý hoặc tóm tắt ngắn. Dùng gạch đầu dòng khi có nhiều ý. Độ dài thường khoảng 150-400 từ; chỉ ngắn hơn khi tài liệu không còn gì liên quan.");
        builder.AppendLine("- Nếu tài liệu viết bằng tiếng Anh, hãy dịch và diễn giải sang tiếng Việt; không chèn câu hoặc cụm từ tiếng Anh, chỉ giữ nguyên mã môn, tên viết tắt chuẩn và tên công nghệ.");
        builder.AppendLine("- Chỉ dùng thông tin trong ngữ cảnh tài liệu ở trên.");
        builder.AppendLine("- Nếu ngữ cảnh không đủ để trả lời, hãy nói: Không tìm thấy thông tin này trong tài liệu đã tải lên.");
        builder.AppendLine("- Không bịa nội dung, không suy đoán ngoài tài liệu.");
        builder.AppendLine("- Không tự tạo tên tài liệu, số trang, số slide hoặc nguồn tham khảo.");
        builder.AppendLine("- Không cần liệt kê nguồn ở cuối câu trả lời; hệ thống sẽ hiển thị nguồn tham khảo từ các chunk đã truy xuất.");

        return builder.ToString();
    }

    private static string BuildEnglish(string question, IReadOnlyList<RetrievedChunkDto> chunks)
    {
        var builder = new StringBuilder();
        builder.AppendLine("You are a study assistant chatbot for university students.");
        builder.AppendLine("Your task is to answer based on the provided document context.");
        builder.AppendLine();
        builder.AppendLine("Student question:");
        builder.AppendLine(question.Trim());
        builder.AppendLine();
        builder.AppendLine("Document context:");

        if (chunks.Count == 0)
        {
            builder.AppendLine("No relevant document chunks.");
        }
        else
        {
            foreach (var (chunk, index) in chunks.Select((chunk, index) => (chunk, index)))
            {
                builder.AppendLine($"[Source {index + 1}] {chunk.OriginalFileName}");
                builder.AppendLine($"Chunk: {chunk.ChunkIndex}");
                if (chunk.PageNumber.HasValue)
                {
                    builder.AppendLine($"Page: {chunk.PageNumber.Value}");
                }

                if (chunk.SlideNumber.HasValue)
                {
                    builder.AppendLine($"Slide: {chunk.SlideNumber.Value}");
                }

                builder.AppendLine($"Similarity: {chunk.SimilarityScore:0.######}");
                builder.AppendLine("Content:");
                builder.AppendLine(chunk.Content);
                builder.AppendLine();
            }
        }

        builder.AppendLine("Answer rules:");
        builder.AppendLine("- The student asked in English, so answer only in English, clearly and in an academic tone.");
        builder.AppendLine("- Give a complete answer, not a terse one: state the direct answer first, then explain the details, examples or related context found in the documents, and end with a short note or summary. Use bullet points when there are several points. Aim for roughly 150-400 words; go shorter only when the documents hold nothing more that is relevant.");
        builder.AppendLine("- If the documents are written in Vietnamese, translate and explain them in English; do not include Vietnamese sentences or phrases.");
        builder.AppendLine("- Only use information from the document context above.");
        builder.AppendLine("- If the context is not enough to answer, say: This information was not found in the uploaded documents.");
        builder.AppendLine("- Do not make up content or speculate beyond the documents.");
        builder.AppendLine("- Do not invent document names, page numbers, slide numbers or references.");
        builder.AppendLine("- Do not list sources at the end of the answer; the system displays the references from the retrieved chunks.");

        return builder.ToString();
    }
}
