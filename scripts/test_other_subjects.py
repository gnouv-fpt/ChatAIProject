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
    print("=" * 80)
    print("KIỂM THỬ SESSION 1: MÔN SWD392 (KIẾN TRÚC & THIẾT KẾ PHẦN MỀM - HK7)")
    print("=" * 80)
    history_swd = []
    swd_turns = [
        "Môn SWD392 có mấy tín chỉ và thi PE chiếm bao nhiêu %?",
        "thế thi cuối kỳ chiếm bao nhiêu % và hình thức thế nào",
        "môn này học ở học kỳ mấy",
        "tiên quyết của nó là gì",
        "cấu trúc điểm chi tiết gồm những gì",
        "Cho em lời khuyên và lộ trình 10 tuần để pass môn này"
    ]
    for idx, q in enumerate(swd_turns, 1):
        res, lat = post_chat({"question": q, "history": history_swd})
        ans = res.get("answer", "")
        prov = res.get("provider", "")
        print(f"\n[SWD392 - LƯỢT {idx}] ({lat}ms | Provider: {prov})")
        print(f"Hỏi: {q}")
        print(f"Đáp:\n{ans}")
        history_swd.append({"role": "user", "content": q})
        history_swd.append({"role": "assistant", "content": ans})

    print("\n" + "=" * 80)
    print("KIỂM THỬ SESSION 2: MÔN SWP391 (ĐỒ ÁN PHÁT TRIỂN PHẦN MỀM - HK5)")
    print("=" * 80)
    history_swp = []
    swp_turns = [
        "Môn SWP391 có mấy tín chỉ và có thi PE không?",
        "tiên quyết của môn này gồm những môn nào",
        "cấu trúc điểm và hình thức bảo vệ đồ án ra sao"
    ]
    for idx, q in enumerate(swp_turns, 1):
        res, lat = post_chat({"question": q, "history": history_swp})
        ans = res.get("answer", "")
        prov = res.get("provider", "")
        print(f"\n[SWP391 - LƯỢT {idx}] ({lat}ms | Provider: {prov})")
        print(f"Hỏi: {q}")
        print(f"Đáp:\n{ans}")
        history_swp.append({"role": "user", "content": q})
        history_swp.append({"role": "assistant", "content": ans})

    print("\n" + "=" * 80)
    print("KIỂM THỬ CÁC MÔN ĐẠI CƯƠNG & CHUYÊN NGÀNH KHÁC (MAS291, CEA201, PRM393, CSI106)")
    print("=" * 80)
    other_cases = [
        ("MAS291 (Xác suất thống kê)", "Môn MAS291 có mấy tín chỉ và có thi PE không?"),
        ("CEA201 (Kiến trúc máy tính)", "Môn CEA201 có mấy tín chỉ và thi PE chiếm bao nhiêu %?"),
        ("PRM393 (Lập trình di động)", "Môn PRM393 có mấy tín chỉ và thi PE chiếm bao nhiêu %?"),
        ("CSI106 (Nhập môn CNTT)", "Môn CSI106 có mấy tín chỉ và học ở học kỳ mấy?")
    ]
    for label, q in other_cases:
        res, lat = post_chat({"question": q})
        ans = res.get("answer", "")
        prov = res.get("provider", "")
        print(f"\n[{label}] ({lat}ms | Provider: {prov})")
        print(f"Hỏi: {q}")
        print(f"Đáp:\n{ans}")

if __name__ == "__main__":
    main()

