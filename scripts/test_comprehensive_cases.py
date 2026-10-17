import urllib.request
import json
import time

URL = 'http://127.0.0.1:8000/api/v1/chat'

def post_chat(payload):
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(URL, data=data, headers={'Content-Type': 'application/json; charset=utf-8'})
    t0 = time.time()
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode('utf-8'))
    latency = round((time.time() - t0) * 1000, 2)
    return res, latency

def main():
    print("=" * 70)
    print("KIỂM THỬ 1: CHÍNH XÁC TÍN CHỈ & ĐIỂM THI PE/FE ĐA DẠNG CÁC MÔN")
    print("=" * 70)
    test_courses = [
        ("PRN212 (HK5)", "Môn PRN212 có mấy tín chỉ và thi PE chiếm bao nhiêu %?"),
        ("PRO192 (HK2)", "Môn PRO192 có mấy tín chỉ và thi PE chiếm mấy phần trăm?"),
        ("DBI202 (HK2)", "Môn DBI202 có mấy tín chỉ và thi PE chiếm bao nhiêu %?"),
        ("PRM393 (HK8)", "Môn PRM393 có mấy tín chỉ và thi PE chiếm mấy %?"),
        ("SWE201c (HK3)", "Môn SWE201c có mấy tín chỉ và hình thức thi thế nào?"),
        ("OJT202 (HK6)", "Môn OJT202 có mấy tín chỉ và ở học kỳ mấy?"),
        ("SWP391 (HK5)", "Môn SWP391 có mấy tín chỉ và có thi PE không?")
    ]

    for label, q in test_courses:
        res, lat = post_chat({"question": q})
        provider = res.get("provider", "Unknown")
        ans = res.get("answer", "")
        print(f"\n>>> [{label}] (Latency: {lat}ms | Provider: {provider})")
        print(f"Câu hỏi: {q}")
        print(f"Trả lời: {ans}")

    print("\n" + "=" * 70)
    print("KIỂM THỬ 2: MULTI-TURN CHAT (BÁM SÁT NGỮ CẢNH QUA NHIỀU LƯỢT HỎI)")
    print("=" * 70)
    session_history = []
    multi_turn_questions = [
        "Môn PRN212 có mấy tín chỉ và thi PE chiếm bao nhiêu %?",
        "pe chiếm bao nhiêu %",
        "thế còn thi lý thuyết thì sao",
        "môn này học ở học kỳ mấy",
        "tiên quyết là những môn nào",
        "cấu trúc điểm chi tiết gồm những gì"
    ]

    for idx, q in enumerate(multi_turn_questions, 1):
        payload = {"question": q, "history": session_history}
        res, lat = post_chat(payload)
        provider = res.get("provider", "Unknown")
        ans = res.get("answer", "")
        print(f"\n>>> [LƯỢT {idx}] (Latency: {lat}ms | Provider: {provider})")
        print(f"Hỏi: {q}")
        print(f"Đáp: {ans}")
        session_history.append({"role": "user", "content": q})
        session_history.append({"role": "assistant", "content": ans})

    print("\n" + "=" * 70)
    print("KIỂM THỬ 3: KẾ HOẠCH HỌC TẬP 10 TUẦN & NGUYÊN TẮC TIÊN QUYẾT (FPT STANDARDS)")
    print("=" * 70)
    plan_q = "Cho em lời khuyên và phân bổ kế hoạch học tập 10 tuần để pass môn PRN212"
    res_plan, lat_plan = post_chat({"question": plan_q})
    provider = res_plan.get("provider", "Unknown")
    ans_plan = res_plan.get("answer", "")
    print(f"\n>>> [TƯ VẤN LỘ TRÌNH] (Latency: {lat_plan}ms | Provider: {provider})")
    print(f"Câu hỏi: {plan_q}")
    print(f"Nội dung phản hồi:\n{ans_plan}")

if __name__ == "__main__":
    main()

