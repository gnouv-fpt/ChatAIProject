import asyncio
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from backend.app.schemas.chat import ChatRequest
from backend.app.services.rag_engine import RAGEngine

sys.stdout.reconfigure(encoding='utf-8')

test_cases = [
    {
        "title": "CA 1: Sinh viên mất gốc, sợ PE môn CSD201, mục tiêu chỉ cần qua môn",
        "req": ChatRequest(
            question="Tôi bị mất gốc code từ hồi PRO192, giờ sắp học CSD201 tôi sợ trượt PE quá. Tôi chỉ cần qua môn thôi (5.0), chỉ cho tôi cách thoát hiểm với!",
            scope="subject",
            id="CSD201",
            student_context={
                "current_gpa": 5.8,
                "course_goal": "pass",
                "learning_style": "practice",
                "failed_courses": ["PRO192"],
                "retake_count": 1
            }
        )
    },
    {
        "title": "CA 2: Sinh viên GPA 7.4 muốn lên 8.0 (Giỏi), đã trượt 1 môn, hỏi chiến lược kỳ 5",
        "req": ChatRequest(
            question="GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 loại Giỏi thì kỳ 5 này có môn SWP391 và PRN212 tôi nên phân bổ chiến lược ra sao?",
            scope="curriculum",
            id="BIT_SE_K19B",
            student_context={
                "current_gpa": 7.4,
                "target_gpa": 8.0,
                "required_avg_mark": 8.45,
                "retake_count": 1,
                "current_semester": 5
            }
        )
    },
    {
        "title": "CA 3: Sinh viên bế tắc đồ án SWP391 sắp toang deadline",
        "req": ChatRequest(
            question="Ê bro, đồ án SWP391 team tôi lộn xộn quá, sắp tới ngày review sprint mà backend chưa xong, tôi hoang mang không biết qua môn nổi không nữa.",
            scope="subject",
            id="SWP391",
            student_context={
                "current_semester": 5,
                "course_goal": "pass"
            }
        )
    }
]

async def main():
    print("=" * 70)
    print("KIỂM THỬ THỰC CHIẾN MASTER PROMPT: SENIOR PEER BUDDY (GROQ)")
    print("=" * 70)

    engine = RAGEngine()
    engine.initialize()

    output_lines = ["# BÁO CÁO KIỂM THỬ THỰC CHIẾN MASTER PROMPT\n"]

    for i, case in enumerate(test_cases, 1):
        print(f"\n[{i}/3] Đang test: {case['title']}...")
        res = await engine.answer_query(case["req"])
        
        print(f">>> Provider: {res.provider} | Latency: {res.latency_ms:.1f}ms")
        print(f">>> Độ dài phản hồi: {len(res.answer)} ký tự")
        
        preview = res.answer[:300].replace('\n', ' ')
        print(f">>> Preview: {preview}...\n")
        
        output_lines.append(f"## {case['title']}")
        output_lines.append(f"- **Câu hỏi:** {case['req'].question}")
        output_lines.append(f"- **Dữ kiện sinh viên:** `{case['req'].student_context}`")
        output_lines.append(f"- **Thời gian xử lý:** {res.latency_ms:.1f}ms | Provider: {res.provider}")
        output_lines.append("\n### Câu trả lời của AI:\n")
        output_lines.append(res.answer)
        output_lines.append("\n---\n")

    report_path = Path("backend/master_prompt_test_report.md")
    report_path.write_text("\n".join(output_lines), encoding="utf-8")
    print(f"\n[OK] Đã lưu kết quả chi tiết cả 3 ca vào: {report_path}")

if __name__ == "__main__":
    asyncio.run(main())
