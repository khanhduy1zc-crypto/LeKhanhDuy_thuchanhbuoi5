# =====================================================================
#  TH_2026_10_09_Sinh_vien.jl
#  Điều phối giao đơn trong khuôn viên — Cấu trúc dữ liệu và giải thuật
#  Sinh viên: Lê Khánh Duy — MSSV: N24DCDT020
#  Ngày: 09/10/2026
#  Bốn hàm cần hoàn thiện: merge_sort, binary_search, bfs_routes, knapsack
# =====================================================================

module GiaoDon

using Random

export Order, Session, mini_data, mini_profile, read_data, write_result,
       adjacency, merge_sort, binary_search, bfs_routes, knapsack,
       dfs_reachable, brute_force, plan_session, deliver_one!, undo_last!,
       check_invariants, run_mini, demo, queue_values, CHUA_HOAN_THANH

const CHUA_HOAN_THANH = "CHUA_HOAN_THANH: ham chua duoc hoan thien"

# ---------------------------------------------------------------------
# 1. Mô hình dữ liệu
# ---------------------------------------------------------------------
struct Order
    id::Int
    destination::Int      # điểm giao
    service::Int          # thời gian phục vụ
    benefit::Int          # lợi ích
end

Base.show(io::IO, o::Order) = print(io, "Order($(o.id), đích=$(o.destination), phục vụ=$(o.service), lợi ích=$(o.benefit))")

# Node danh sách liên kết đơn (giữ kế hoạch)
mutable struct Node
    id::Int
    next::Union{Node,Nothing}
    Node(id) = new(id, nothing)
end

# Hàng đợi FIFO (đơn chờ giao) — dùng vector làm vòng đệm đơn giản
mutable struct FIFO
    items::Vector{Int}
    FIFO() = new(Int[])
end

enqueue!(q::FIFO, id::Int) = push!(q.items, id)
function dequeue!(q::FIFO)
    isempty(q.items) && error("FIFO rỗng, không thể lấy đơn")
    return popfirst!(q.items)
end
Base.isempty(q::FIFO) = isempty(q.items)
queue_values(q::FIFO) = copy(q.items)
# Hoàn tác: đưa đơn về ĐẦU hàng đợi (giữ nguyên thứ tự trước thao tác)
prepend!(q::FIFO, id::Int) = pushfirst!(q.items, id)

# Ngăn xếp (lịch sử giao)
mutable struct Stack
    items::Vector{Int}
    Stack() = new(Int[])
end
push_stack!(s::Stack, id::Int) = push!(s.items, id)
function pop_stack!(s::Stack)
    isempty(s.items) && error("Stack rỗng, không thể hoàn tác")
    return pop!(s.items)
end
Base.isempty(s::Stack) = isempty(s.items)
stack_values(s::Stack) = copy(s.items)

# BST đơn giản để tra cứu Order theo id (đã cung cấp trong khung)
mutable struct BSTNode
    order::Order
    left::Union{BSTNode,Nothing}
    right::Union{BSTNode,Nothing}
    BSTNode(o) = new(o, nothing, nothing)
end

function bst_insert!(root::Union{BSTNode,Nothing}, o::Order)
    root === nothing && return BSTNode(o)
    if o.id < root.order.id
        root.left = bst_insert!(root.left, o)
    elseif o.id > root.order.id
        root.right = bst_insert!(root.right, o)
    end
    return root
end

function bst_search(root::Union{BSTNode,Nothing}, id::Int)
    root === nothing && return nothing
    if id == root.order.id
        return root.order
    elseif id < root.order.id
        return bst_search(root.left, id)
    else
        return bst_search(root.right, id)
    end
end

# Phiên giao hàng (Session)
mutable struct Session
    orders::Vector{Order}        # danh mục đầy đủ
    by_id::Vector{Order}         # danh mục sắp theo ID tăng (tiền điều kiện tìm kiếm nhị phân)
    bst_root::Union{BSTNode,Nothing}
    routes                       # kết quả BFS: (distance, parent, routes)
    costs::Dict{Int,Int}         # ID -> τ = 2h + service
    budget::Int
    selected::Vector{Int}        # ID được DP chọn
    pending::FIFO                # hàng đợi đơn chờ giao
    history::Stack               # ngăn xếp lịch sử giao
    completed::Vector{Int}       # ID đã giao (theo thứ tự)
    spent::Int                   # tổng thời gian đã dùng
    earned::Int                  # tổng lợi ích đã nhận
    plan_head::Union{Node,Nothing}
end

# ---------------------------------------------------------------------
# 2. Dữ liệu mẫu MINI001 và hồ sơ
# ---------------------------------------------------------------------
function mini_profile()
    return (budget=8, name="MINI001")
end

function mini_data()
    folder = joinpath(@__DIR__, "data_MINI001")
    mkpath(folder)
    # don_hang.csv: id,diem_giao,thoi_gian_phuc_vu,loi_ich
    open(joinpath(folder, "don_hang.csv"), "w") do io
        println(io, "id,diem_giao,thoi_gian_phuc_vu,loi_ich")
        println(io, "1,2,1,6")
        println(io, "2,4,1,8")
        println(io, "3,6,1,10")
    end
    # ban_do.csv: u,v  (vô hướng, mỗi cạnh ghi một lần)
    open(joinpath(folder, "ban_do.csv"), "w") do io
        println(io, "u,v")
        println(io, "1,2")
        println(io, "1,3")
        println(io, "2,4")
        println(io, "3,4")
        println(io, "3,5")
        println(io, "4,6")
        println(io, "5,6")
    end
    return folder
end

# Sinh dữ liệu theo MSSV (8–10 đơn) — phần mở rộng sau buổi
function mssv_data(mssv::AbstractString)
    folder = joinpath(@__DIR__, "data_$(mssv)")
    mkpath(folder)
    # Hạt giống từ MSSV (giữ chuỗi, không mất số 0 đầu)
    seed = sum(Int(c) for c in mssv)
    rng = MersenneTwister(seed)
    n = 8 + (seed % 3)   # 8..10 đơn
    dests = rand(rng, 2:6, n)
    open(joinpath(folder, "don_hang.csv"), "w") do io
        println(io, "id,diem_giao,thoi_gian_phuc_vu,loi_ich")
        for i in 1:n
            sv = rand(rng, 1:3)
            ben = rand(rng, 5:20)
            println(io, "$i,$(dests[i]),$sv,$ben")
        end
    end
    # Bản đồ giữ nguyên 6 đỉnh 7 cạnh của bài
    open(joinpath(folder, "ban_do.csv"), "w") do io
        println(io, "u,v")
        for (u, v) in [(1,2),(1,3),(2,4),(3,4),(3,5),(4,6),(5,6)]
            println(io, "$u,$v")
        end
    end
    return folder
end

# ---------------------------------------------------------------------
# 3. Đọc/ghi CSV (chỉ số nguyên, tiêu đề cố định)
# ---------------------------------------------------------------------
function read_data(folder::AbstractString)
    orders = Order[]
    open(joinpath(folder, "don_hang.csv")) do io
        header = readline(io)
        @assert strip(header) == "id,diem_giao,thoi_gian_phuc_vu,loi_ich" "Sai tiêu đề don_hang.csv"
        for (ln, line) in enumerate(eachline(io))
            isempty(strip(line)) && continue
            parts = split(line, ',')
            length(parts) == 4 || error("Dòng $ln sai số trường: $line")
            id, dest, sv, ben = parse.(Int, strip.(parts))
            push!(orders, Order(id, dest, sv, ben))
        end
    end
    edges = Tuple{Int,Int}[]
    V = 0
    open(joinpath(folder, "ban_do.csv")) do io
        header = readline(io)
        @assert strip(header) == "u,v" "Sai tiêu đề ban_do.csv"
        for (ln, line) in enumerate(eachline(io))
            isempty(strip(line)) && continue
            parts = split(line, ',')
            length(parts) == 2 || error("Dòng $ln sai số trường: $line")
            u, v = parse.(Int, strip.(parts))
            push!(edges, (u, v))
            V = max(V, u, v)
        end
    end
    return (orders=orders, edges=edges, V=V, folder=folder)
end

function write_result(s::Session, folder::AbstractString)
    path = joinpath(folder, "ket_qua.csv")
    open(path, "w") do io
        println(io, "id,diem_giao,thoi_gian_phuc_vu,loi_ich,duong_di,so_canh,tau,duoc_chon,da_giao")
        for o in s.orders
            h = s.routes.distance[o.destination]
            path_str = join(s.routes.routes[o.destination], "->")
            tau = get(s.costs, o.id, -1)
            chon = o.id in s.selected ? 1 : 0
            giao = o.id in s.completed ? 1 : 0
            println(io, "$(o.id),$(o.destination),$(o.service),$(o.benefit),\"$path_str\",$h,$tau,$chon,$giao")
        end
    end
    return path
end

# ---------------------------------------------------------------------
# 4. Danh sách kề (vô hướng) + tái dùng merge_sort để xếp láng giềng
# ---------------------------------------------------------------------
function adjacency(edges, V=0)
    if V == 0
        for (u, v) in edges; V = max(V, u, v); end
    end
    g = [Int[] for _ in 1:V]
    for (u, v) in edges
        push!(g[u], v)
        push!(g[v], u)   # vô hướng: thêm cả hai chiều
    end
    # Chuẩn hóa thứ tự láng giềng tăng dần để tái lập lượt BFS
    for u in 1:V
        g[u] = merge_sort(g[u], (<))
    end
    return g
end

# DFS kiểm tra tới được (đã cung cấp)
function dfs_reachable(graph, source)
    V = length(graph)
    seen = falses(V)
    function dfs(u)
        seen[u] = true
        for v in graph[u]
            !seen[v] && dfs(v)
        end
    end
    dfs(source)
    return seen
end

# =====================================================================
#  NV1 · merge_sort(a, before)  — ĐÃ HOÀN THIỆN
#  Chia để trị: chia đôi, sắp đệ quy, trộn hai dãy đã có thứ tự.
#  Trả dãy MỚI, không sửa a. Giữ ổn định: khi hòa, lấy nhánh trái trước.
# =====================================================================
function merge_sort(a::AbstractVector, before::Function)
    n = length(a)
    n ≤ 1 && return copy(a)            # điều kiện dừng
    mid = n ÷ 2
    left  = merge_sort(a[1:mid], before)
    right = merge_sort(a[mid+1:end], before)
    res = similar(a)
    i = j = k = 1
    L, R = length(left), length(right)
    # Trộn: bất biến — phần đã xuất có thứ tự theo before
    while i ≤ L && j ≤ R
        if before(right[j], left[i])   # phần tử phải đứng trước -> lấy phải
            res[k] = right[j]; j += 1
        else                            # lấy trái (kể cả khi hòa -> ổn định)
            res[k] = left[i];  i += 1
        end
        k += 1
    end
    while i ≤ L; res[k] = left[i];  i += 1; k += 1; end   # chép dư trái
    while j ≤ R; res[k] = right[j]; j += 1; k += 1; end   # chép dư phải
    return res
end

# =====================================================================
#  NV2 · binary_search(a::Vector{Order}, id::Int)  — ĐÃ HOÀN THIỆN
#  Tiền điều kiện: a đã sắp TĂNG theo Order.id, id duy nhất.
#  Trả Order tìm được hoặc nothing.
# =====================================================================
function binary_search(a::Vector{Order}, id::Int)
    left = 1
    right = length(a)
    while left ≤ right
        mid = left + (right - left) ÷ 2   # tránh tràn số
        if a[mid].id == id
            return a[mid]
        elseif a[mid].id < id
            left = mid + 1                 # loại nửa trái (đã loại mid)
        else
            right = mid - 1                # loại nửa phải
        end
    end
    return nothing                         # đoạn rỗng -> không tồn tại
end

# =====================================================================
#  NV3 · bfs_routes(graph, source=1)  — ĐÃ HOÀN THIỆN
#  Đồ thị KHÔNG TRỌNG SỐ. Dùng FIFO. Đánh dấu ngay khi phát hiện.
#  Trả (distance, parent, routes). Đỉnh không tới: distance=-1, đường rỗng.
# =====================================================================
function bfs_routes(graph, source=1)
    V = length(graph)
    distance = fill(-1, V)
    parent   = fill(0, V)
    distance[source] = 0
    fifo = [source]                       # hàng đợi: dùng vector + chỉ số đọc
    head = 1
    while head ≤ length(fifo)
        u = fifo[head]; head += 1         # lấy đầu FIFO
        for v in graph[u]
            if distance[v] == -1          # chưa tới -> phát hiện lần đầu
                distance[v] = distance[u] + 1
                parent[v] = u
                push!(fifo, v)            # đánh dấu TRƯỚC khi đưa vào hàng đợi
            end
        end
    end
    # Dựng đường đi cho mỗi đỉnh: lần ngược parent rồi đảo
    routes = [Int[] for _ in 1:V]
    for v in 1:V
        distance[v] == -1 && continue     # không tới -> giữ đường rỗng
        path = Int[]
        cur = v
        while cur != 0
            push!(path, cur)
            cur = parent[cur]
        end
        routes[v] = reverse(path)         # nguồn -> đích
    end
    return (distance=distance, parent=parent, routes=routes)
end

# =====================================================================
#  NV4 · knapsack(orders, costs, budget)  — ĐÃ HOÀN THIỆN
#  Ba lô 0/1: F(i,b) = lợi ích tốt nhất xét i đơn đầu, ngân sách b.
#  Julia: table[i+1, b+1] = F(i,b). Nhánh lấy dùng HÀNG TRƯỚC (i-1).
#  Trả (ids, value, cost, table).
# =====================================================================
function knapsack(orders, costs, budget)
    n = length(orders)
    B = budget
    # Hàng/cột cơ sở: i=0 hoặc b=0 -> 0 (zeros đã khởi tạo sẵn)
    table = zeros(Int, n + 1, B + 1)
    for i in 1:n
        o = orders[i]
        τ = costs[o.id]                  # tra bằng ID, không dùng vị trí
        val = o.benefit
        for b in 0:B
            if τ > b
                table[i+1, b+1] = table[i, b+1]          # không lấy
            else
                table[i+1, b+1] = max(
                    table[i, b+1],                       # không lấy đơn i
                    val + table[i, b - τ + 1]            # lấy đơn i -> hàng trước
                )
            end
        end
    end
    # Truy vết từ F(n, B) = table[n+1, B+1]
    ids = Int[]
    b = B
    for i in n:-1:1
        o = orders[i]
        τ = costs[o.id]
        # Nếu đã lấy đơn i: giá trị ô hiện tại = val + ô hàng trước ở b-τ
        if τ ≤ b && table[i+1, b+1] == table[i, b - τ + 1] + o.benefit
            push!(ids, o.id)
            b -= τ
        end
        # ngược lại: không lấy, giữ b, chuyển sang i-1
    end
    reverse!(ids)                          # theo thứ tự ID tăng
    cost  = sum(costs[id] for id in ids; init=0)
    value = sum(o.benefit for o in orders if o.id in ids; init=0)
    return (ids=ids, value=value, cost=cost, table=table)
end

# Vét cạn đối chiếu (đã cung cấp): duyệt 2^n tập con
function brute_force(orders, costs, budget)
    n = length(orders)
    best_val = 0
    best_ids = Int[]
    for mask in 0:(2^n - 1)
        ids = Int[]
        c = 0; v = 0
        for i in 1:n
            if (mask >> (i-1)) & 1 == 1
                o = orders[i]
                push!(ids, o.id)
                c += costs[o.id]
                v += o.benefit
            end
        end
        if c ≤ budget && v > best_val
            best_val = v
            best_ids = ids
        end
    end
    return (ids=sort(best_ids), value=best_val)
end

# ---------------------------------------------------------------------
# 5. Lập kế hoạch, giao, hoàn tác, bất biến
# ---------------------------------------------------------------------
function plan_session(data, budget)
    orders = data.orders
    # NV1: sắp danh mục theo ID tăng -> tiền điều kiện tìm kiếm nhị phân
    by_id = merge_sort(orders, (x, y) -> x.id < y.id)
    # BST đối chiếu
    bst_root = nothing
    for o in by_id; bst_root = bst_insert!(bst_root, o); end
    # NV3: BFS từ kho 1
    graph = adjacency(data.edges, data.V)
    routes = bfs_routes(graph, 1)
    # Tính costs = Dict(ID -> τ = 2h + service)
    costs = Dict{Int,Int}()
    for o in orders
        h = routes.distance[o.destination]
        h == -1 && error("Điểm giao $(o.destination) của đơn $(o.id) không tới được")
        costs[o.id] = 2 * h + o.service
    end
    # NV4: DP chọn đơn
    dp = knapsack(by_id, costs, budget)
    # Thứ tự ưu tiên giảm theo lợi ích/τ (tái dùng merge_sort)
    prio = merge_sort(dp.ids, (a, b) -> begin
        oa = binary_search(by_id, a); ob = binary_search(by_id, b)
        ra = oa.benefit * costs[b]; rb = ob.benefit * costs[a]
        ra != rb ? ra > rb : a < b
    end)
    pending = FIFO()
    for id in prio; enqueue!(pending, id); end
    # Danh sách liên kết kế hoạch
    head = nothing
    for id in reverse(prio)
        node = Node(id); node.next = head; head = node
    end
    return Session(orders, by_id, bst_root, routes, costs, budget,
                   dp.ids, pending, Stack(), Int[], 0, 0, head)
end

function deliver_one!(s::Session)
    isempty(s.pending) && error("Không còn đơn chờ giao")
    id = dequeue!(s.pending)
    o = binary_search(s.by_id, id)
    o === nothing && error("Tra cứu binary_search không thấy ID $id")
    # Đối chiếu với BST
    o_bst = bst_search(s.bst_root, id)
    @assert o_bst !== nothing && o_bst.id == id "BST và binary_search không khớp"
    τ = s.costs[id]
    s.spent += τ
    s.earned += o.benefit
    push!(s.completed, id)
    push_stack!(s.history, id)
    return id
end

function undo_last!(s::Session)
    isempty(s.history) && error("Lịch sử rỗng, không thể hoàn tác")
    id = pop_stack!(s.history)
    o = binary_search(s.by_id, id)
    s.spent -= s.costs[id]
    s.earned -= o.benefit
    pop!(s.completed)
    prepend!(s.pending, id)        # đưa về ĐẦU FIFO, giữ nguyên thứ tự cũ
    return id
end

# Bất biến: không mất, không lặp đơn
function check_invariants(s::Session)
    sel = Set(s.selected)
    pen = Set(queue_values(s.pending))
    com = Set(s.completed)
    # 1. chờ và đã giao không giao nhau
    isempty(pen ∩ com) || return false
    # 2. hợp = tập chọn
    pen ∪ com == sel || return false
    # 3. tổng thời gian/lợi ích khớp
    sum(s.costs[id] for id in s.completed; init=0) == s.spent || return false
    sum(o.benefit for o in s.orders if o.id in s.completed; init=0) == s.earned || return false
    # 4. không vượt ngân sách
    s.spent ≤ s.budget || return false
    # 5. không lặp trong completed
    length(s.completed) == length(Set(s.completed)) || return false
    return true
end

# ---------------------------------------------------------------------
# 6. Chạy demo mini, menu
# ---------------------------------------------------------------------
function run_mini()
    folder = mini_data()
    data = read_data(folder)
    p = mini_profile()
    s = plan_session(data, p.budget)
    # Demo: giao 1, hoàn tác, rồi giao hết kế hoạch
    deliver_one!(s)          # giao ID 1
    undo_last!(s)            # hoàn tác ngay
    while !isempty(s.pending)
        deliver_one!(s)      # giao lại ID 1 rồi ID 2
    end
    write_result(s, folder)
    return s
end

function demo()
    folder = mini_data()
    data = read_data(folder)
    p = mini_profile()
    println("=== Bộ dữ liệu ", p.name, " (B=", p.budget, ") ===")
    println("Đơn hàng: ", [(o.id, o.destination, o.service, o.benefit) for o in data.orders])
    println("Cạnh: ", data.edges)
    s = plan_session(data, p.budget)
    println("Khoảng cách BFS từ 1: ", s.routes.distance)
    println("Chi phí τ: ", sort(collect(s.costs)))
    println("DP chọn: ID=", s.selected, " cost=", sum(s.costs[i] for i in s.selected), " lợi ích=", sum(o.benefit for o in s.orders if o.id in s.selected))
    println("FIFO chờ: ", queue_values(s.pending))
    println("-- Giao đơn 1 --")
    deliver_one!(s)
    println("FIFO=", queue_values(s.pending), " lịch sử=", stack_values(s.history), " spent=", s.spent, " earned=", s.earned)
    println("-- Hoàn tác --")
    undo_last!(s)
    println("FIFO=", queue_values(s.pending), " lịch sử=", stack_values(s.history), " spent=", s.spent, " earned=", s.earned)
    println("-- Giao hết kế hoạch --")
    while !isempty(s.pending)
        id = deliver_one!(s)
        println("  giao ID=$id, FIFO=", queue_values(s.pending), " spent=", s.spent, " earned=", s.earned)
    end
    println("Hoàn thành: ", s.completed, " spent=", s.spent, " earned=", s.earned)
    println("Bất biến: ", check_invariants(s) ? "ĐẠT" : "KHÔNG ĐẠT")
    path = write_result(s, folder)
    println("Kết quả xuất tại: ", path)
    return s
end

function menu()
    folder = mini_data()
    data = read_data(folder)
    p = mini_profile()
    s = plan_session(data, p.budget)
    while true
        println("\n--- MENU ---")
        println("1. Xem kế hoạch (FIFO)")
        println("2. Giao một đơn")
        println("3. Hoàn tác lần giao cuối")
        println("4. Xem trạng thái")
        println("5. Xuất CSV kết quả")
        println("0. Thoát")
        print("Lựa chọn: ")
        choice = strip(readline())
        if choice == "1"
            println("Đơn chờ: ", queue_values(s.pending))
        elseif choice == "2"
            try
                id = deliver_one!(s)
                println("Đã giao ID=$id")
            catch e
                println("Lỗi: ", e.msg)
            end
        elseif choice == "3"
            try
                id = undo_last!(s)
                println("Đã hoàn tác ID=$id")
            catch e
                println("Lỗi: ", e.msg)
            end
        elseif choice == "4"
            println("Đã giao: ", s.completed, " spent=", s.spent, " earned=", s.earned)
            println("Bất biến: ", check_invariants(s) ? "ĐẠT" : "KHÔNG ĐẠT")
        elseif choice == "5"
            path = write_result(s, folder)
            println("Đã xuất: ", path)
        elseif choice == "0"
            break
        else
            println("Lựa chọn không hợp lệ")
        end
    end
end

end # module GiaoDon

# ---------------------------------------------------------------------
# 7. Điểm vào chương trình
# ---------------------------------------------------------------------
using .GiaoDon
using Random

function main()
    args = ARGS
    if isempty(args)
        println("Cách dùng:")
        println("  julia TH_2026_10_09_Sinh_vien.jl --data        # tạo + đọc bộ MINI001")
        println("  julia TH_2026_10_09_Sinh_vien.jl --mini        # chạy demo đầy đủ mini")
        println("  julia TH_2026_10_09_Sinh_vien.jl --demo        # demo có in từng bước")
        println("  julia TH_2026_10_09_Sinh_vien.jl --menu        # menu tương tác")
        println("  julia TH_2026_10_09_Sinh_vien.jl <MSSV> --data # sinh dữ liệu theo MSSV")
        return
    end
    if args[1] == "--data"
        folder = mini_data()
        data = read_data(folder)
        println("Đã tạo và đọc bộ MINI001 tại: ", folder)
        println("Đơn hàng: ", [(o.id, o.destination, o.service, o.benefit) for o in data.orders])
        println("Cạnh: ", data.edges)
    elseif args[1] == "--mini"
        s = run_mini()
        println("spent=", s.spent, " earned=", s.earned, " completed=", s.completed)
        println("Bất biến: ", check_invariants(s) ? "ĐẠT" : "KHÔNG ĐẠT")
    elseif args[1] == "--demo"
        demo()
    elseif args[1] == "--menu"
        menu()
    elseif length(args) ≥ 2 && args[2] == "--data"
        mssv = args[1]
        folder = mssv_data(mssv)
        data = read_data(folder)
        println("Đã tạo dữ liệu theo MSSV $mssv tại: ", folder)
        println("Số đơn: ", length(data.orders))
    else
        println("Tham số không hợp lệ: ", args)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
