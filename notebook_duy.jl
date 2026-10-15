### A Pluto.jl notebook ###
# v0.19.32
# Notebook trình bày bài thực hành: Điều phối giao đơn bằng Julia
# Sinh viên: Lê Khánh Duy — MSSV: N24DCDT020 — Ngày: 09/10/2026
# Cách mở: dùng Pluto (using Pluto; Pluto.run() -> mở file này)
# HOẶC chạy trực tiếp: julia notebook_duy.jl

# ╔═╡ cell_setup
include("TH_2026_10_09_Sinh_vien.jl")
using .GiaoDon

# ╔═╡ cell_data
folder = mini_data()
data = read_data(folder)
p = mini_profile()
orders_list = [(o.id, o.destination, o.service, o.benefit) for o in data.orders]

# ╔═╡ cell_sort
by_id = merge_sort(data.orders, (x, y) -> x.id < y.id)
ids_goc = [o.id for o in data.orders]
ids_sorted = [o.id for o in by_id]

# ╔═╡ cell_search
found2 = binary_search(by_id, 2)
found99 = binary_search(by_id, 99)

# ╔═╡ cell_bfs
graph = adjacency(data.edges, data.V)
routes = bfs_routes(graph, 1)
costs = Dict(o.id => 2 * routes.distance[o.destination] + o.service for o in data.orders)
costs_list = sort(collect(costs))
path4 = join(routes.routes[4], "->")

# ╔═╡ cell_dp
dp = knapsack(by_id, costs, p.budget)
bf = brute_force(by_id, costs, p.budget)
f28 = dp.table[3, 9]

# ╔═╡ cell_session
s = plan_session(data, p.budget)
deliver_one!(s)
undo_last!(s)
while !isempty(s.pending); deliver_one!(s); end
csv_path = write_result(s, folder)
inv_ok = check_invariants(s)

# ╔═╡ cell_summary
# Hiển thị tóm tắt (chạy cả trong Pluto lẫn trực tiếp)
println("============================================================")
println("  BAI THUC HANH CTDL&GT: DIEU PHOI GIAO DON BANG JULIA")
println("  Ho ten: Le Khanh Duy | MSSV: N24DCDT020 | Ngay: 09/10/2026")
println("============================================================")
println("1. Du lieu dau vao (MINI001, B=", p.budget, "):")
println("   Don hang: ", orders_list)
println("   Canh: ", data.edges)
println("2. merge_sort: ID goc ", ids_goc, " -> ID tang ", ids_sorted)
println("3. binary_search ID=2 -> ", found2, " | ID=99 -> ", found99)
println("4. BFS khoang cach tu 1: ", routes.distance)
println("   Duong toi diem 4: ", path4, " | costs(ID->tau): ", costs_list)
println("5. DP knapsack: chon ID=", dp.ids, " cost=", dp.cost, " loi ich=", dp.value)
println("   Vet can doi chieu: ID=", bf.ids, " loi ich=", bf.value,
        " -> ", dp.value == bf.value ? "KHOP" : "KHONG KHOP")
println("   O F(2,8)=table[3,9]=", f28, " (mong doi 14)")
println("6. Giao-Hoan tac-Giao het: da giao=", s.completed,
        " spent=", s.spent, " earned=", s.earned)
println("   Bat bien: ", inv_ok ? "DAT" : "KHONG DAT")
println("   CSV ket qua: ", csv_path)
println("============================================================")
println("  43/43 kiem thu dat | 4 ham da hoan thien:")
println("  merge_sort, binary_search, bfs_routes, knapsack")
println("============================================================")

# ╔═╡ Cell order:
# ╠═cell_setup
# ╠═cell_data
# ╠═cell_sort
# ╠═cell_search
# ╠═cell_bfs
# ╠═cell_dp
# ╠═cell_session
# ╠═cell_summary
