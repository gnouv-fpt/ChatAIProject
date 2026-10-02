"""Detect the language of a student question so the answer can mirror it."""
import re
from typing import Literal

Language = Literal["vi", "en"]

VIETNAMESE = "vi"
ENGLISH = "en"

_VIETNAMESE_CHARS = re.compile(
    r"[đĐàáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹ"
    r"ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸ]"
)

# Common words of unaccented Vietnamese ("mon nay hoc gi") and of English.
# Words shared by both ("can" = cần, "the" = thế, "do") are left out of both lists.
_VIETNAMESE_WORDS = {
    "la", "gi", "cua", "va", "cho", "em", "anh", "chi", "toi", "minh", "ban", "nhung",
    "khong", "nao", "mon", "hoc", "ky", "nay", "duoc", "nhu", "sao", "bao", "nhieu",
    "phai", "co", "voi", "thi", "ve", "trong", "nen", "lam", "hay", "giup",
    "tai", "lieu", "diem", "qua", "truot", "dau", "tien", "quyet", "bai", "kiem",
    "tra", "mot", "nhe", "oi", "vay", "roi", "chua", "gium", "huong", "dan",
}
_ENGLISH_WORDS = {
    "what", "how", "is", "are", "which", "does", "should", "my", "to", "of", "for",
    "about", "course", "courses", "subject", "subjects", "semester", "and", "with",
    "prerequisite", "prerequisites", "exam", "exams", "when", "why", "who", "this",
    "that", "need", "learn", "study", "please", "tell", "me", "explain", "pass",
    "grade", "credits", "you", "it", "in", "on", "i", "an",
    "document", "documents", "chapter", "lecture", "slide", "summarize", "define",
}
_WORD = re.compile(r"[a-zA-Z]+")


def detect_language(text: str) -> Language:
    """Return "en" for English questions, otherwise "vi" (the project default)."""
    if not text:
        return VIETNAMESE
    if _VIETNAMESE_CHARS.search(text):
        return VIETNAMESE

    words = [w.lower() for w in _WORD.findall(text)]
    vi_hits = sum(1 for w in words if w in _VIETNAMESE_WORDS)
    en_hits = sum(1 for w in words if w in _ENGLISH_WORDS)
    return ENGLISH if en_hits > vi_hits else VIETNAMESE
