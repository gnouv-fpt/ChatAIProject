using System.Text.RegularExpressions;

namespace BusinessLogic.Infrastructure.Implementations;

public enum AnswerLanguage
{
    Vietnamese,
    English
}

/// <summary>
/// Detects the language of a student question so the answer can mirror it.
/// Falls back to Vietnamese, the project's default language.
/// </summary>
public static partial class QuestionLanguageDetector
{
    private const string VietnameseLetters =
        "đĐàáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹ" +
        "ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸ";

    // Common words of unaccented Vietnamese ("mon nay hoc gi") and of English.
    // Words shared by both ("can" = cần, "the" = thế, "do") are left out of both sets.
    private static readonly HashSet<string> VietnameseWords =
    [
        "la", "gi", "cua", "va", "cho", "em", "anh", "chi", "toi", "minh", "ban", "nhung",
        "khong", "nao", "mon", "hoc", "ky", "nay", "duoc", "nhu", "sao", "bao", "nhieu",
        "phai", "co", "voi", "thi", "ve", "trong", "nen", "lam", "hay", "giup",
        "tai", "lieu", "diem", "qua", "truot", "dau", "tien", "quyet", "bai", "kiem",
        "tra", "mot", "nhe", "oi", "vay", "roi", "chua", "gium", "huong", "dan"
    ];

    private static readonly HashSet<string> EnglishWords =
    [
        "what", "how", "is", "are", "which", "does", "should", "my", "to", "of", "for",
        "about", "course", "courses", "subject", "subjects", "semester", "and", "with",
        "prerequisite", "prerequisites", "exam", "exams", "when", "why", "who", "this",
        "that", "need", "learn", "study", "please", "tell", "me", "explain", "pass",
        "grade", "credits", "you", "it", "in", "on", "i", "an",
        "document", "documents", "chapter", "lecture", "slide", "summarize", "define"
    ];

    public static AnswerLanguage Detect(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return AnswerLanguage.Vietnamese;
        }

        if (text.IndexOfAny(VietnameseLetters.ToCharArray()) >= 0)
        {
            return AnswerLanguage.Vietnamese;
        }

        var vietnameseHits = 0;
        var englishHits = 0;
        foreach (Match match in WordRegex().Matches(text))
        {
            var word = match.Value.ToLowerInvariant();
            if (VietnameseWords.Contains(word))
            {
                vietnameseHits++;
            }
            else if (EnglishWords.Contains(word))
            {
                englishHits++;
            }
        }

        return englishHits > vietnameseHits ? AnswerLanguage.English : AnswerLanguage.Vietnamese;
    }

    [GeneratedRegex("[A-Za-z]+")]
    private static partial Regex WordRegex();
}
