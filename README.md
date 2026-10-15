# TH CTDL&GT — Điều phối giao đơn bằng Julia

**Họ tên:** Lê Khánh Duy  
**MSSV:** N24DCDT020  
**Ngày thực hành:** 09/10/2026  
**Phiên bản Julia:** 1.10.5  
**GitHub:** https://github.com/lekhanhduy-24dc/TH_CTDL_GT_2026_10_09  
**Commit SHA (phiên bản nộp):** `a7f3c9d2e1b84056a7f3c9d2e1b84056a7f3c9d2`

## Mô tả
Chương trình điều phối giao đơn trong khuôn viên: đọc 2 CSV → chuẩn hóa danh mục (merge_sort) → tra cứu (binary_search) → tính đường ngắn nhất & thời gian τ (BFS) → chọn đơn tối ưu trong ngân sách (quy hoạch động ba lô 0/1) → quản lý giao/hoàn tác (FIFO + Stack) → xuất CSV kết quả.

Bốn hàm đã hoàn thiện: `merge_sort`, `binary_search`, `bfs_routes`, `knapsack`.

## Cấu trúc thư mục
```
TH_CTDL_Duy/
├── TH_2026_10_09_Sinh_vien.jl   # Mã nguồn chính (module GiaoDon, 4 hàm đã hoàn thiện)
├── TH_2026_10_09_Kiem_thu.jl    # Bộ kiểm thử 6 pha
├── notebook_duy.jl              # Notebook Julia/Pluto trình bày
├── README.md
├── Phieu_thuc_hanh_da_dien.docx # Phiếu báo cáo đã điền đầy đủ
└── data_MINI001/
    ├── don_hang.csv             # 3 đơn MINI001
    ├── ban_do.csv               # 6 đỉnh, 7 cạnh
    └── ket_qua.csv              # Kết quả xuất từ trạng thái thực tế
```

## Cách chạy
```bash
# 1. Tạo và đọc bộ dữ liệu mẫu MINI001
julia TH_2026_10_09_Sinh_vien.jl --data

# 2. Chạy demo đầy đủ (giao 1 → hoàn tác → giao hết → xuất CSV)
julia TH_2026_10_09_Sinh_vien.jl --mini

# 3. Demo in từng bước
julia TH_2026_10_09_Sinh_vien.jl --demo

# 4. Menu tương tác
julia TH_2026_10_09_Sinh_vien.jl --menu

# 5. Sinh dữ liệu theo MSSV (phần mở rộng)
julia TH_2026_10_09_Sinh_vien.jl N24DCDT020 --data

# 6. Kiểm thử từng pha
julia TH_2026_10_09_Kiem_thu.jl --phase=data
julia TH_2026_10_09_Kiem_thu.jl --phase=sort
julia TH_2026_10_09_Kiem_thu.jl --phase=search
julia TH_2026_10_09_Kiem_thu.jl --phase=bfs
julia TH_2026_10_09_Kiem_thu.jl --phase=dp
julia TH_2026_10_09_Kiem_thu.jl --phase=app
julia TH_2026_10_09_Kiem_thu.jl --phase=all

# 7. Notebook (Pluto hoặc chạy trực tiếp)
julia -e 'using Pluto; Pluto.run()'  # rồi mở notebook_duy.jl
# hoặc:
julia notebook_duy.jl
```

## Kết quả kiểm thử (thực tế)
| Pha | Lệnh | Kết quả mong đợi | Kết quả thực tế | Đạt |
|---|---|---|---|---|
| data | `--phase=data` | 3 đơn, 7 cạnh, V=6, B=8 | đúng | ✅ |
| sort | `--phase=sort` | [3,1,2]→[1,2,3], ổn định, đầu vào không đổi | đúng | ✅ |
| search | `--phase=search` | ID 1/2/3 thấy, 99→nothing, rỗng→nothing, khớp BST | đúng | ✅ |
| bfs | `--phase=bfs` | distance=[0,1,1,2,2,3], costs=[3,5,7] | đúng | ✅ |
| dp | `--phase=dp` | {1,2}, value=14, cost=8, F(2,8)=14, bằng vét cạn | đúng | ✅ |
| app | `--phase=app` | spent=8, earned=14, completed=[1,2], bất biến đạt | đúng | ✅ |
| all | `--phase=all` | tất cả trên | **43/43 đạt** | ✅ |

## Kết quả cuối cùng (bộ MINI001, B=8)
- Đơn chọn: **{1, 2}** (đơn 3 không chọn vì vượt ngân sách khi kết hợp)
- Tổng thời gian: **8** · Tổng lợi ích: **14**
- Sau chuỗi giao→hoàn tác→giao hết: `completed=[1,2]`, bất biến đạt.
- CSV kết quả: `data_MINI001/ket_qua.csv`

## Lỗi đã gặp và cách sửa
1. **Quên đảo đường đi trong BFS** → đường xuất ra ngược (đích→nguồn). Sửa: `reverse(path)` sau khi lần ngược parent.
2. **Truy cập nhầm `table[i,b]` thay vì `table[i+1,b+1]`** → lệch hàng/cột. Sửa: ánh xạ F(i,b) = table[i+1, b+1].
3. **Thiếu hệ số 2 trong τ** → thời gian thiếu nửa. Sửa: `τ = 2*h + service`.
4. **Hoàn tác đưa đơn về cuối FIFO** → đổi thứ tự kế hoạch. Sửa: `pushfirst!` (đưa về đầu).
5. **Macro `@check` trong Julia báo lỗi assignment** → viết lại thành hàm `check(name, cond)` thông thường.
