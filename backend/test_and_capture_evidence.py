import httpx
import time
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

API_URL = "http://127.0.0.1:8000/api/v1/chat"

test_scenarios = [
    {
        "id": "TEST-01",
        "category": "Cá nhân hóa sâu & Cảnh báo quy chế FLM",
        "question": "GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 loại Giỏi thì kỳ 5 này có môn SWP391 và PRN212 tôi nên phân bổ chiến lược ra sao?",
        "payload": {
            "question": "GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 loại Giỏi thì kỳ 5 này có môn SWP391 và PRN212 tôi nên phân bổ chiến lược ra sao?",
            "scope": "curriculum",
            "id": "BIT_SE_K19B",
            "student_context": {
                "current_gpa": 7.4,
                "target_gpa": 8.0,
                "required_avg_mark": 8.45,
                "retake_count": 1,
                "current_semester": 5
            }
        }
    },
    {
        "id": "TEST-02",
        "category": "Bám sát đề cương chính thống FLM (PRM392 PE & Trọng số điểm)",
        "question": "Môn PRM392 có thi PE không, chiếm bao nhiêu % điểm và cần luyện những kỹ năng gì theo CLO đề cương?",
        "payload": {
            "question": "Môn PRM392 có thi PE không, chiếm bao nhiêu % điểm và cần luyện những kỹ năng gì theo CLO đề cương?",
            "scope": "subject",
            "id": "PRM392"
        }
    },
    {
        "id": "TEST-03",
        "category": "Chống ảo giác (Anti-Hallucination) với môn học ngoài phạm vi",
        "question": "Môn Nấu ăn ẩm thực Á Âu học ở học kỳ mấy trong ngành Kỹ thuật phần mềm K19B?",
        "payload": {
            "question": "Môn Nấu ăn ẩm thực Á Âu học ở học kỳ mấy trong ngành Kỹ thuật phần mềm K19B?",
            "scope": "curriculum",
            "id": "BIT_SE_K19B"
        }
    },
    {
        "id": "TEST-04",
        "category": "Chiến lược thoát hiểm môn CSD201 cho sinh viên yếu code",
        "question": "Tôi bị mất gốc lập trình từ PRO192, kỳ này phải học CSD201. Chỉ cần qua môn (5.0) thì tôi phải tập trung vào những đầu điểm nào trong đề cương?",
        "payload": {
            "question": "Tôi bị mất gốc lập trình từ PRO192, kỳ này phải học CSD201. Chỉ cần qua môn (5.0) thì tôi phải tập trung vào những đầu điểm nào trong đề cương?",
            "scope": "subject",
            "id": "CSD201",
            "student_context": {
                "current_gpa": 5.6,
                "course_goal": "pass",
                "failed_courses": ["PRO192"],
                "retake_count": 1
            }
        }
    }
]

def run():
    print("=" * 70)
    print("CHẠY TEST VÀ THU THẬP BẰNG CHỨNG HỆ THỐNG RAG GROQ (3 ACC X ROBUST)")
    print("=" * 70)

    report_lines = [
        "# BÁO CÁO BẰNG CHỨNG KIỂM THỬ HỆ THỐNG CHAT FLM AI",
        f"**Thời gian thực hiện:** {time.strftime('%Y-%m-%d %H:%M:%S')}",
        "**Mô hình sử dụng:** Groq `qwen/qwen3.8-27b` (3 Accounts Pool: akkhanh, zikzak, khanhtrangamer)",
        "**Nguồn dữ liệu:** Dữ liệu đề cương chính thống cào từ FLM (`flm_knowledge_vault/*.md`)",
        "\n---\n"
    ]

    with httpx.Client(timeout=60.0) as client:
        # Check health
        health = client.get("http://127.0.0.1:8000/api/v1/health").json()
        print(f"[Health Check] Status: {health.get('status')} | Provider: {health.get('active_llm_provider')} | Chunks: {health.get('total_chunks')}")
        report_lines.append(f"### Trạng thái Backend\n- **Trạng thái:** `{health.get('status')}`\n- **Provider đang hoạt động:** `{health.get('active_llm_provider')}`\n- **Số lượng môn / chunks trong vault:** {health.get('total_courses')} môn / {health.get('total_chunks')} chunks\n\n---\n")

        for item in test_scenarios:
            print(f"\n[Running {item['id']}] {item['category']}...")
            t0 = time.time()
            resp = client.post(API_URL, json=item["payload"])
            elapsed = time.time() - t0

            if resp.status_code == 200:
                data = resp.json()
                answer = data.get("answer", "")
                sources = data.get("sources", [])
                provider = data.get("provider", "")
                latency = data.get("latency_ms", elapsed * 1000)

                print(f"  -> Thành công trong {elapsed:.2f}s | Provider: {provider} | Trích dẫn: {len(sources)} nguồn")
                
                report_lines.append(f"## {item['id']}: {item['category']}")
                report_lines.append(f"**Câu hỏi:** *\"{item['question']}\"*")
                if "student_context" in item["payload"]:
                    report_lines.append(f"**Hồ sơ sinh viên truyền vào:** `{json.dumps(item['payload']['student_context'], ensure_ascii=False)}`")
                report_lines.append(f"**Thời gian phản hồi:** `{latency:.1f}ms` ({elapsed:.2f}s) | **Provider:** `{provider}`")
                report_lines.append(f"**Nguồn tài liệu chính thống trích dẫn:** {', '.join([f'`{s}`' for s in sources]) if sources else '*(Không có - từ chối ngoài phạm vi)*'}")
                report_lines.append("\n**Câu trả lời thực tế từ AI:**\n")
                report_lines.append(f"> {answer.replace(chr(10), chr(10) + '> ')}")
                report_lines.append("\n---\n")
            else:
                print(f"  -> Thất bại: HTTP {resp.status_code}: {resp.text}")
                report_lines.append(f"## {item['id']}: {item['category']} - THẤT BẠI")
                report_lines.append(f"Lỗi HTTP {resp.status_code}: {resp.text}\n---\n")

            # Pause 1s between questions
            time.sleep(1.0)

    evidence_file = Path("backend/test_evidence_report.md")
    evidence_file.write_text("\n".join(report_lines), encoding="utf-8")
    print(f"\n[HOÀN TẤT] Toàn bộ bằng chứng đã được lưu vào: {evidence_file}")

if __name__ == "__main__":
    run()
