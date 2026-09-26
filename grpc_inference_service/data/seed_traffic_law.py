from typing import List, Dict, Any

def get_seed_traffic_law_chunks() -> List[Dict[str, Any]]:
    """
    Returns authentic curated Vietnamese road traffic law chunks from thuvienphapluat.vn.
    Includes active verified documents (Decree 100/2019/ND-CP, Decree 123/2021/ND-CP)
    and an outdated document (Decree 46/2016/ND-CP) to demonstrate Data Verification Engine.
    """
    return [
        # --- NGHỊ ĐỊNH 100/2019/NĐ-CP & 123/2021/NĐ-CP: NỒNG ĐỘ CỒN ---
        {
            "chunk_id": "chunk-nong-do-con-o-to-muc-1",
            "document_title": "Nghị định 100/2019/NĐ-CP",
            "document_number": "100/2019/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 5",
            "clause": "Khoản 6 Điểm c",
            "content": (
                "Phạt tiền từ 6.000.000 đồng đến 8.000.000 đồng đối với người điều khiển xe ô tô "
                "và các loại xe tương tự xe ô tô điều khiển xe trên đường mà trong máu hoặc hơi thở "
                "có nồng độ cồn nhưng chưa vượt quá 50 miligam/100 mililít máu hoặc chưa vượt quá "
                "0,25 miligam/1 lít khí thở. Hình phạt bổ sung: Tước quyền sử dụng Giấy phép lái xe từ 10 tháng đến 12 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Nghi-dinh-100-2019-ND-CP-xu-phat-vi-pham-hanh-chinh-giao-thong-duong-bo-duong-sat-430063.aspx",
            "is_verified": True,
            "is_active": True
        },
        {
            "chunk_id": "chunk-nong-do-con-o-to-muc-2",
            "document_title": "Nghị định 100/2019/NĐ-CP",
            "document_number": "100/2019/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 5",
            "clause": "Khoản 7 Điểm c",
            "content": (
                "Phạt tiền từ 16.000.000 đồng đến 18.000.000 đồng đối với người điều khiển xe ô tô "
                "và các loại xe tương tự xe ô tô điều khiển xe trên đường mà trong máu hoặc hơi thở "
                "có nồng độ cồn vượt quá 50 miligam đến 80 miligam/100 mililít máu hoặc vượt quá "
                "0,25 miligam đến 0,4 miligam/1 lít khí thở. Tước quyền sử dụng Giấy phép lái xe từ 16 tháng đến 18 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Nghi-dinh-100-2019-ND-CP-xu-phat-vi-pham-hanh-chinh-giao-thong-duong-bo-duong-sat-430063.aspx",
            "is_verified": True,
            "is_active": True
        },
        {
            "chunk_id": "chunk-nong-do-con-o-to-muc-3",
            "document_title": "Nghị định 100/2019/NĐ-CP",
            "document_number": "100/2019/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 5",
            "clause": "Khoản 8 Điểm a",
            "content": (
                "Phạt tiền từ 30.000.000 đồng đến 40.000.000 đồng đối với người điều khiển xe ô tô "
                "và các loại xe tương tự xe ô tô điều khiển xe trên đường mà trong máu hoặc hơi thở "
                "có nồng độ cồn vượt quá 80 miligam/100 mililít máu hoặc vượt quá 0,4 miligam/1 lít khí thở, "
                "hoặc không chấp hành yêu cầu kiểm tra về nồng độ cồn của người thi hành công vụ. "
                "Tước quyền sử dụng Giấy phép lái xe từ 22 tháng đến 24 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Nghi-dinh-100-2019-ND-CP-xu-phat-vi-pham-hanh-chinh-giao-thong-duong-bo-duong-sat-430063.aspx",
            "is_verified": True,
            "is_active": True
        },
        {
            "chunk_id": "chunk-nong-do-con-xe-may-muc-1",
            "document_title": "Nghị định 100/2019/NĐ-CP",
            "document_number": "100/2019/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 6",
            "clause": "Khoản 6 Điểm c",
            "content": (
                "Phạt tiền từ 2.000.000 đồng đến 3.000.000 đồng đối với người điều khiển xe mô tô, xe gắn máy "
                "(kể cả xe máy điện) điều khiển xe trên đường mà trong máu hoặc hơi thở có nồng độ cồn "
                "nhưng chưa vượt quá 50 miligam/100 mililít máu hoặc chưa vượt quá 0,25 miligam/1 lít khí thở. "
                "Tước quyền sử dụng Giấy phép lái xe từ 10 tháng đến 12 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Nghi-dinh-100-2019-ND-CP-xu-phat-vi-pham-hanh-chinh-giao-thong-duong-bo-duong-sat-430063.aspx",
            "is_verified": True,
            "is_active": True
        },
        {
            "chunk_id": "chunk-nong-do-con-xe-may-muc-3",
            "document_title": "Nghị định 100/2019/NĐ-CP",
            "document_number": "100/2019/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 6",
            "clause": "Khoản 8 Điểm e",
            "content": (
                "Phạt tiền từ 6.000.000 đồng đến 8.000.000 đồng đối với người điều khiển xe mô tô, xe gắn máy "
                "điều khiển xe trên đường mà trong máu hoặc hơi thở có nồng độ cồn vượt quá 80 miligam/100 mililít máu "
                "hoặc vượt quá 0,4 miligam/1 lít khí thở. Tước quyền sử dụng Giấy phép lái xe từ 22 tháng đến 24 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Nghi-dinh-100-2019-ND-CP-xu-phat-vi-pham-hanh-chinh-giao-thong-duong-bo-duong-sat-430063.aspx",
            "is_verified": True,
            "is_active": True
        },

        # --- VƯỢT ĐÈN ĐỎ, ĐÈN VÀNG (SỬA ĐỔI BỞI NĐ 123/2021/NĐ-CP) ---
        {
            "chunk_id": "chunk-den-do-o-to",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 5",
            "clause": "Khoản 5 Điểm a",
            "content": (
                "Phạt tiền từ 4.000.000 đồng đến 6.000.000 đồng đối với người điều khiển xe ô tô không chấp hành "
                "hiệu lệnh của đèn tín hiệu giao thông (vượt đèn đỏ hoặc đèn vàng khi chưa vào giao lộ). "
                "Ngoài ra, người điều khiển xe vi phạm còn bị tước quyền sử dụng Giấy phép lái xe từ 01 tháng đến 03 tháng; "
                "nếu gây tai nạn giao thông thì bị tước quyền sử dụng Giấy phép lái xe từ 02 tháng đến 04 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },
        {
            "chunk_id": "chunk-den-do-xe-may",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 6",
            "clause": "Khoản 4 Điểm e",
            "content": (
                "Phạt tiền từ 800.000 đồng đến 1.000.000 đồng đối với người điều khiển xe mô tô, xe gắn máy "
                "(kể cả xe máy điện) không chấp hành hiệu lệnh của đèn tín hiệu giao thông (vượt đèn đỏ, đèn vàng trái quy định). "
                "Bị tước quyền sử dụng Giấy phép lái xe từ 01 tháng đến 03 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },

        # --- MŨ BẢO HIỂM (SỬA ĐỔI BỞI NGHỊ ĐỊNH 123/2021/NĐ-CP) ---
        {
            "chunk_id": "chunk-mu-bao-hiem-xe-may",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 6",
            "clause": "Khoản 2 Điểm b, Điểm n",
            "content": (
                "Phạt tiền từ 400.000 đồng đến 600.000 đồng đối với người điều khiển xe mô tô, xe gắn máy "
                "không đội mũ bảo hiểm cho người đi mô tô, xe máy hoặc đội mũ bảo hiểm cho người đi mô tô, xe máy "
                "không cài quai đúng quy cách khi tham gia giao thông trên đường bộ; hoặc chở người ngồi trên xe không đội mũ bảo hiểm "
                "hoặc đội mũ bảo hiểm không cài quai đúng quy cách (trừ trường hợp chở người bệnh đi cấp cứu, trẻ em dưới 06 tuổi, áp giải người có hành vi vi phạm pháp luật)."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },

        # --- SỬ DỤNG ĐIỆN THOẠI DI ĐỘNG ---
        {
            "chunk_id": "chunk-dien-thoai-o-to",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 5",
            "clause": "Khoản 4 Điểm a",
            "content": (
                "Phạt tiền từ 2.000.000 đồng đến 3.000.000 đồng đối với người điều khiển xe ô tô dùng tay sử dụng điện thoại di động "
                "khi đang điều khiển xe chạy trên đường. Bị tước quyền sử dụng Giấy phép lái xe từ 01 tháng đến 03 tháng nếu gây tai nạn."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },
        {
            "chunk_id": "chunk-dien-thoai-xe-may",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 6",
            "clause": "Khoản 4 Điểm h",
            "content": (
                "Phạt tiền từ 800.000 đồng đến 1.000.000 đồng đối với người điều khiển xe mô tô, xe gắn máy "
                "sử dụng điện thoại di động, thiết bị âm thanh (trừ thiết bị trợ thính) khi đang điều khiển phương tiện tham gia giao thông. "
                "Tước quyền sử dụng Giấy phép lái xe từ 01 tháng đến 03 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },

        # --- CHẠY QUÁ TỐC ĐỘ QUY ĐỊNH ---
        {
            "chunk_id": "chunk-qua-toc-do-o-to",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 5",
            "clause": "Khoản 3, Khoản 5, Khoản 7",
            "content": (
                "Mức xử phạt chạy quá tốc độ đối với người điều khiển xe ô tô:\n"
                "- Chạy quá tốc độ từ 05 km/h đến dưới 10 km/h: Phạt tiền từ 800.000 đồng đến 1.000.000 đồng.\n"
                "- Chạy quá tốc độ từ 10 km/h đến 20 km/h: Phạt tiền từ 4.000.000 đồng đến 6.000.000 đồng, tước GPLX 01 đến 03 tháng.\n"
                "- Chạy quá tốc độ trên 20 km/h đến 35 km/h: Phạt tiền từ 6.000.000 đồng đến 8.000.000 đồng, tước GPLX 02 đến 04 tháng.\n"
                "- Chạy quá tốc độ trên 35 km/h: Phạt tiền từ 10.000.000 đồng đến 12.000.000 đồng, tước GPLX từ 02 tháng đến 04 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },

        # --- ĐI NGƯỢC CHIỀU ---
        {
            "chunk_id": "chunk-di-nguoc-chieu-o-to",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 5",
            "clause": "Khoản 5 Điểm c, Khoản 8 Điểm a",
            "content": (
                "Phạt tiền từ 4.000.000 đồng đến 6.000.000 đồng đối với người điều khiển xe ô tô đi ngược chiều của đường một chiều, "
                "đi ngược chiều trên đường có biển 'Cấm đi ngược chiều' (trừ xe ưu tiên). Tước quyền sử dụng Giấy phép lái xe từ 02 đến 04 tháng.\n"
                "Đặc biệt: Điều khiển xe đi ngược chiều trên đường cao tốc, lùi xe trên đường cao tốc bị phạt tiền từ 16.000.000 đồng đến 18.000.000 đồng, "
                "tước quyền sử dụng Giấy phép lái xe từ 05 tháng đến 07 tháng."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },

        # --- GIẤY PHÉP LÁI XE (GPLX) ---
        {
            "chunk_id": "chunk-khong-gplx-xe-may",
            "document_title": "Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP)",
            "document_number": "123/2021/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 21",
            "clause": "Khoản 5, Khoản 7",
            "content": (
                "Phạt tiền từ 1.000.000 đồng đến 2.000.000 đồng đối với người điều khiển xe mô tô hai bánh có dung tích xi lanh dưới 175 cm3 "
                "không có Giấy phép lái xe hoặc sử dụng Giấy phép lái xe không do cơ quan có thẩm quyền cấp.\n"
                "Phạt tiền từ 4.000.000 đồng đến 5.000.000 đồng đối với người điều khiển xe mô tô hai bánh có dung tích xi lanh từ 175 cm3 trở lên mà không có Giấy phép lái xe."
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-123-2021-ND-CP-sua-doi-Nghi-dinh-xu-phat-vi-pham-hanh-chinh-hang-hai-duong-bo-499120.aspx",
            "is_verified": True,
            "is_active": True
        },

        # --- OUTDATED CHUNK: NGHỊ ĐỊNH 46/2016/NĐ-CP (ĐÃ HẾT HIỆU LỰC) ---
        # Chunk này phục vụ cho việc kiểm thử tính năng Data Verification Engine (phải bị lọc bỏ)
        {
            "chunk_id": "chunk-outdated-mu-bao-hiem-nd46",
            "document_title": "Nghị định 46/2016/NĐ-CP",
            "document_number": "46/2016/NĐ-CP",
            "chapter": "Chương II",
            "article": "Điều 6",
            "clause": "Khoản 3 Điểm i",
            "content": (
                "Phạt tiền từ 100.000 đồng đến 200.000 đồng đối với người điều khiển xe mô tô không đội mũ bảo hiểm. "
                "[CẢNH BÁO: QUY ĐỊNH NÀY ĐÃ HẾT HIỆU LỰC TỪ 01/01/2020 THEO NGHỊ ĐỊNH 100/2019/NĐ-CP]"
            ),
            "source_url": "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Nghi-dinh-46-2016-ND-CP-xu-phat-vi-pham-hanh-chinh-giao-thong-duong-bo-duong-sat-313589.aspx",
            "is_verified": False,
            "is_active": False
        }
    ]
