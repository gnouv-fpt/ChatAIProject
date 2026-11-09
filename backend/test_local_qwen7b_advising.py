import asyncio
import sys
import time
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

import httpx
from backend.app.services.rag_engine import rag_engine
from backend.app.schemas.chat import ChatRequest

sys.stdout.reconfigure(encoding='utf-8')

async def main():
    print("=" * 70)
    print("TEST THỰC TẾ QWEN2.5:7B (CHẠY 100% OFFLINE TRÊN NVIDIA RTX 4050)")
    print("=" * 70)

    # 1. Check GPU memory
    try:
        import subprocess
        smi = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=name,memory.used,memory.total", "--format=csv,noheader,nounits"],
            text=True
        ).strip()
        print(f"[GPU Status] {smi}")
    except Exception as e:
        print(f"[GPU Status] {e}")

    # 2. Prepare real student query with FLM context
    csd201_path = Path("flm_knowledge_vault/CSD201.md")
    context = csd201_path.read_text(encoding="utf-8")[:3000] if csd201_path.exists() else ""

    question = (
        "Em là sinh viên K19 ngành SE, sắp tới học môn CSD201 mà nền tảng code hơi yếu. "
        "Nhờ anh tiền bối tư vấn giúp em chiến lược phân bổ học tập, cách vượt qua bài thi PE "
        "và những cạm bẫy hay mất điểm nhất trong đề cương môn này!"
    )

    system_prompt = (
        "Bạn là một người bạn tiền bối (Senior Peer) xuất sắc ngành Kỹ thuật Phần mềm của Đại học FPT. "
        "Bạn trò chuyện chân thành, thực chiến, thấu hiểu áp lực thi PE, bám sát 100% dữ liệu đề cương FLM, "
        "không nói đạo lý sáo rỗng, đưa ra hành động kỹ thuật cụ thể bằng tiếng Việt."
    )

    user_prompt = f"""=== DỮ LIỆU ĐỀ CƯƠNG FLM CSD201 ===
{context}

=== CÂU HỎI CỦA SINH VIÊN ===
{question}

=== YÊU CẦU ===
Trả lời bằng tiếng Việt tự nhiên, có cấu trúc markdown rõ ràng, phân tích sâu các đầu điểm và chiến thuật thực chiến."""

    print("\n[Đang gửi prompt đến qwen2.5:7b qua Ollama Local]...")
    t0 = time.time()
    async with httpx.AsyncClient(timeout=180.0) as client:
        resp = await client.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "qwen2.5:7b",
                "system": system_prompt,
                "prompt": user_prompt,
                "stream": False,
                "options": {
                    "temperature": 0.3,
                    "num_predict": 1200
                }
            }
        )
    elapsed = time.time() - t0

    if resp.status_code == 200:
        data = resp.json()
        ans = data.get("response", "")
        eval_count = data.get("eval_count", 0)
        eval_duration = data.get("eval_duration", 1) / 1e9
        tok_sec = eval_count / eval_duration if eval_duration > 0 else 0

        print(f"\n>>> Hoàn thành trong: {elapsed:.2f}s | Tốc độ: {tok_sec:.1f} tokens/s | Tổng: {eval_count} tokens")
        print(f">>> Độ dài câu trả lời: {len(ans)} ký tự\n")
        print("=" * 50)
        print("NỘI DUNG CÂU TRẢ LỜI CỦA QWEN 2.5 7B:")
        print("=" * 50)
        print(ans)

        # Save to evidence report
        report_file = Path("backend/qwen7b_local_test_evidence.md")
        content = f"""# BẰNG CHỨNG KIỂM THỬ MODEL LOCAL QWEN 2.5 7B (OFFLINE)

- **Mô hình:** `qwen2.5:7b` (Lượng tử hóa 4-bit, 4.7 GB)
- **Vị trí lưu trữ:** `E:\\AI-Video-Translation\\Models\\Ollama` (Ổ E, không tốn dung lượng ổ C)
- **Phần cứng xử lý:** NVIDIA GeForce RTX 4050 Laptop GPU (6GB VRAM)
- **Thời gian xử lý:** {elapsed:.2f} giây
- **Tốc độ sinh text:** {tok_sec:.1f} tokens/giây ({eval_count} tokens)
- **Dữ liệu nguồn:** Đề cương FLM chính thống (`flm_knowledge_vault/CSD201.md`)

## Câu hỏi của sinh viên:
> {question}

## Phản hồi thực tế từ Qwen 2.5 7B Local:
{ans}
"""
        report_file.write_text(content, encoding="utf-8")
        print(f"\n[OK] Đã lưu báo cáo bằng chứng vào: {report_file}")
    else:
        print(f"Lỗi: {resp.status_code} - {resp.text}")

if __name__ == "__main__":
    asyncio.run(main())
