import asyncio
import time
import sys
from pathlib import Path
import httpx

import os

sys.stdout.reconfigure(encoding='utf-8')

GROQ_KEY = os.environ.get("GROQ_API_KEY", "")
GROQ_MODEL = "qwen/qwen3.8-27b"
OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "qwen3:4b-instruct"

# Load real CSD201 syllabus context
csd201_path = Path("flm_knowledge_vault/CSD201.md")
context = ""
if csd201_path.exists():
    context = csd201_path.read_text(encoding="utf-8")[:3000]

question = (
    "Tôi sắp học môn CSD201 (Cấu trúc dữ liệu và giải thuật). "
    "Hãy tư vấn chi tiết lộ trình học tập từng tuần, phương pháp luyện code PE "
    "và chiến lược đạt điểm Giỏi (> 8.0) cho môn này dựa trên cấu trúc đánh giá."
)

system_prompt = (
    "Bạn là Cố vấn học tập AI chuyên sâu của Đại học FPT (hệ thống FLM). "
    "Nhiệm vụ của bạn là tư vấn lộ trình học tập, phân bổ thời gian và chiến lược ôn thi rõ ràng, "
    "thực tế, có cấu trúc markdown rành mạch bằng tiếng Việt."
)

user_prompt = f"""=== DỮ LIỆU FLM MÔN CSD201 ===
{context}

=== CÂU HỎI CỦA SINH VIÊN ===
{question}

=== YÊU CẦU TRẢ LỜI ===
Chỉ trả lời bằng tiếng Việt. Trình bày có cấu trúc rõ ràng:
1. Đánh giá độ khó và trọng tâm môn CSD201
2. Kế hoạch ôn tập theo từng giai đoạn
3. Chiến lược đạt điểm cao kỳ thi PE (Practical Exam)
4. Lời khuyên phân bổ thời gian thực tế."""

async def run_groq():
    print(f"\n[1] Đang gửi truy vấn tới Groq ({GROQ_MODEL})...")
    t0 = time.time()
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {GROQ_KEY}"},
            json={
                "model": GROQ_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "temperature": 0.3,
                "max_tokens": 1800,
            }
        )
    elapsed = time.time() - t0
    if resp.status_code == 200:
        ans = resp.json()["choices"][0]["message"]["content"]
        return elapsed, ans
    else:
        return elapsed, f"LỖI ({resp.status_code}): {resp.text}"

async def run_ollama():
    print(f"\n[2] Đang gửi truy vấn tới Local Ollama ({OLLAMA_MODEL})...")
    t0 = time.time()
    async with httpx.AsyncClient(timeout=180.0) as client:
        resp = await client.post(
            OLLAMA_URL,
            json={
                "model": OLLAMA_MODEL,
                "system": system_prompt,
                "prompt": user_prompt,
                "stream": False,
                "options": {
                    "temperature": 0.3,
                    "num_predict": 1500,
                }
            }
        )
    elapsed = time.time() - t0
    if resp.status_code == 200:
        ans = resp.json().get("response", "")
        return elapsed, ans
    else:
        return elapsed, f"LỖI ({resp.status_code}): {resp.text}"

async def main():
    print("=" * 60)
    print("SO SÁNH THỰC TẾ: GROQ (QWEN-3.8-27B) vs OLLAMA LOCAL (QWEN3-4B)")
    print("=" * 60)
    
    groq_time, groq_ans = await run_groq()
    print(f"\n>>> GROQ ({GROQ_MODEL}) hoàn thành trong: {groq_time:.2f}s (Độ dài: {len(groq_ans)} ký tự)")
    
    ollama_time, ollama_ans = await run_ollama()
    print(f"\n>>> OLLAMA ({OLLAMA_MODEL}) hoàn thành trong: {ollama_time:.2f}s (Độ dài: {len(ollama_ans)} ký tự)")
    
    # Save results to a report file
    report = f"""# KẾT QUẢ SO SÁNH GROQ VS OLLAMA LOCAL

## 1. Tổng quan hiệu năng
- **Groq ({GROQ_MODEL})**: {groq_time:.2f} giây | {len(groq_ans)} ký tự | Chi phí: 0đ (Free tier)
- **Local Ollama ({OLLAMA_MODEL})**: {ollama_time:.2f} giây | {len(ollama_ans)} ký tự | Chi phí: 0đ (Chạy trên máy)

## 2. Câu trả lời từ Groq ({GROQ_MODEL}) - {groq_time:.2f}s
{groq_ans}

---

## 3. Câu trả lời từ Ollama Local ({OLLAMA_MODEL}) - {ollama_time:.2f}s
{ollama_ans}
"""
    Path("backend/benchmark_result.md").write_text(report, encoding="utf-8")
    print("\nĐã lưu kết quả chi tiết vào backend/benchmark_result.md")

if __name__ == "__main__":
    asyncio.run(main())
