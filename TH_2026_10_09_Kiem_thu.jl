# =====================================================================
#  TH_2026_10_09_Kiem_thu.jl
#  Kiểm thử từng pha cho bài thực hành điều phối giao đơn
#  Sinh viên: Lê Khánh Duy — MSSV: N24DCDT020
#  Cách dùng: julia TH_2026_10_09_Kiem_thu.jl --phase=<data|sort|search|bfs|dp|app|all>
# =====================================================================

include("TH_2026_10_09_Sinh_vien.jl")
using .GiaoDon

passed = 0
total = 0

function check(name::AbstractString, cond)
    global total, passed
    total += 1
    try
        if cond
            passed += 1
            println("  [PASS] ", name)
        else
            println("  [FAIL] ", name, " (biểu thức sai)")
        end
    catch e
        println("  [FAIL] ", name, " — lỗi: ", e)
    end
end

function setup()
    folder = mini_data()
    data = read_data(folder)
    p = mini_profile()
    return (folder=folder, data=data, p=p)
end

function phase_data()
    println("== PHA: data ==")
    st = setup()
    check("đọc được 3 đơn", length(st.data.orders) == 3)
    check("đơn 1 đúng", st.data.orders[1] == Order(1,2,1,6))
    check("đơn 2 đúng", st.data.orders[2] == Order(2,4,1,8))
    check("đơn 3 đúng", st.data.orders[3] == Order(3,6,1,10))
    check("đọc được 7 cạnh", length(st.data.edges) == 7)
    check("số đỉnh = 6", st.data.V == 6)
    check("ngân sách = 8", st.p.budget == 8)
end

function phase_sort()
    println("== PHA: sort ==")
    st = setup()
    check("merge_sort [3,1,2] -> [1,2,3]", merge_sort([3,1,2], (<)) == [1,2,3])
    check("merge_sort rỗng", merge_sort(Int[], (<)) == Int[])
    check("merge_sort 1 phần tử", merge_sort([42], (<)) == [42])
    by_id = merge_sort(st.data.orders[[3,1,2]], (x,y)->x.id < y.id)
    check("sắp Order theo ID tăng", [o.id for o in by_id] == [1,2,3])
    check("bản ghi giữ nguyên trường", by_id[2].destination == 4 && by_id[2].benefit == 8)
    stab = merge_sort([(1,"a"),(2,"b"),(3,"c")], (x,y)->false)
    check("ổn định khi hòa", [s for (_,s) in stab] == ["a","b","c"])
    orig = [3,1,2]; merge_sort(orig, (<))
    check("đầu vào không đổi", orig == [3,1,2])
end

function phase_search()
    println("== PHA: search ==")
    st = setup()
    by_id = merge_sort(st.data.orders, (x,y)->x.id < y.id)
    f2 = binary_search(by_id, 2)
    check("tìm ID 2 (giữa)", f2 !== nothing && f2.id == 2 && f2.destination == 4 && f2.benefit == 8)
    f1 = binary_search(by_id, 1)
    check("tìm ID 1 (đầu)", f1 !== nothing && f1.id == 1)
    f3 = binary_search(by_id, 3)
    check("tìm ID 3 (cuối)", f3 !== nothing && f3.id == 3)
    check("ID không tồn tại -> nothing", binary_search(by_id, 99) === nothing)
    check("mảng rỗng -> nothing", binary_search(Order[], 1) === nothing)
    bst_root = nothing
    for o in by_id; bst_root = GiaoDon.bst_insert!(bst_root, o); end
    ok = true
    for o in by_id
        bs = binary_search(by_id, o.id)
        bt = GiaoDon.bst_search(bst_root, o.id)
        ok &= (bs !== nothing && bt !== nothing && bs.id == bt.id && bs.destination == bt.destination)
    end
    check("binary_search khớp BST", ok)
end

function phase_bfs()
    println("== PHA: bfs ==")
    st = setup()
    graph = adjacency(st.data.edges, st.data.V)
    routes = bfs_routes(graph, 1)
    check("khoảng cách đúng [0,1,1,2,2,3]", routes.distance == [0,1,1,2,2,3])
    check("đường tới 2 = [1,2]", routes.routes[2] == [1,2])
    check("đường tới 4 bắt đầu 1 kết thúc 4", routes.routes[4][1]==1 && routes.routes[4][end]==4)
    check("số cạnh đường tới 4 = distance[4]", length(routes.routes[4])-1 == routes.distance[4])
    costs = Dict(o.id => 2*routes.distance[o.destination] + o.service for o in st.data.orders)
    check("costs [3,5,7]", [costs[i] for i in 1:3] == [3,5,7])
    g2 = [[2],[1],Int[]]
    r2 = bfs_routes(g2, 1)
    check("đỉnh không tới distance=-1", r2.distance[3] == -1 && isempty(r2.routes[3]))
end

function phase_dp()
    println("== PHA: dp ==")
    st = setup()
    graph = adjacency(st.data.edges, st.data.V)
    routes = bfs_routes(graph, 1)
    costs = Dict(o.id => 2*routes.distance[o.destination] + o.service for o in st.data.orders)
    by_id = merge_sort(st.data.orders, (x,y)->x.id < y.id)
    r = knapsack(by_id, costs, 8)
    check("tập chọn {1,2}", Set(r.ids) == Set([1,2]))
    check("value=14", r.value == 14)
    check("cost=8", r.cost == 8)
    check("table[end,end]=14", r.table[end,end] == 14)
    r0 = knapsack(by_id, costs, 0)
    check("B=0 tập rỗng", isempty(r0.ids) && r0.cost==0 && r0.value==0)
    r1 = knapsack(by_id, costs, 2)
    check("B=2 tập rỗng", isempty(r1.ids))
    check("ID không lặp", length(r.ids) == length(Set(r.ids)))
    bf = brute_force(by_id, costs, 8)
    check("DP bằng vét cạn", r.value == bf.value)
    check("F(2,8)=table[3,9]=14", r.table[3,9] == 14)
end

function phase_app()
    println("== PHA: app ==")
    s = run_mini()
    check("spent=8", s.spent == 8)
    check("earned=14", s.earned == 14)
    check("completed=[1,2]", s.completed == [1,2])
    check("FIFO rỗng sau khi giao hết", isempty(queue_values(s.pending)))
    check("bất biến đạt", check_invariants(s))
    st = setup()
    s2 = plan_session(st.data, st.p.budget)
    check("sau kế hoạch FIFO=[1,2]", queue_values(s2.pending) == [1,2])
    deliver_one!(s2)
    check("sau giao 1: FIFO=[2], lịch sử=[1], spent=3, earned=6",
        queue_values(s2.pending)==[2] && GiaoDon.stack_values(s2.history)==[1] && s2.spent==3 && s2.earned==6)
    undo_last!(s2)
    check("sau hoàn tác: FIFO=[1,2], lịch sử=[], spent=0, earned=0",
        queue_values(s2.pending)==[1,2] && isempty(GiaoDon.stack_values(s2.history)) && s2.spent==0 && s2.earned==0)
end

function main()
    phase = "all"
    for a in ARGS
        if startswith(a, "--phase=")
            phase = split(a, "=")[2]
        end
    end
    if phase == "data"; phase_data()
    elseif phase == "sort"; phase_sort()
    elseif phase == "search"; phase_search()
    elseif phase == "bfs"; phase_bfs()
    elseif phase == "dp"; phase_dp()
    elseif phase == "app"; phase_app()
    elseif phase == "all"
        phase_data(); phase_sort(); phase_search(); phase_bfs(); phase_dp(); phase_app()
    else
        println("Pha không hợp lệ: ", phase)
        return
    end
    println("\n=> Kết quả: $passed / $total kiểm thử đạt")
    if passed == total
        println("=> TAT CA DAT ✅")
    else
        println("=> CON $(total-passed) kiem thu chua dat ❌")
    end
end

main()
