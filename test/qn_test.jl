@testsetup module RandomSetup
using Random: seed!
seed!(42)
end

@testsetup module ExampleQN
export qn_size, max_eq_depth, domains, qn
using GraphDynamicalSystems

qn_size = 3
max_eq_depth = 3
domains = [1:5, 1:5, 1:5]
qn = sample_qualitative_network(qn_size, domains, max_eq_depth)
end

@testitem "QN Grammar Creation" begin
    entities = [:a, :b, :c]
    constants = [i for i = 0:10]
    g = build_qn_grammar(entities, constants)

    @test issubset(Set(entities), Set(g.rules))
    @test issubset(Set(constants), Set(g.rules))
end

@testitem "QN Graph Correctness" begin
    import GraphDynamicalSystems: EntityName
    import MetaGraphsNext: edge_labels

    entity_labels = [:a, :b, :c]
    target_fns = Union{Expr,Integer,Symbol}[:(-c), :a, :b]
    domains = [0:2 for _ = 1:3]

    qn = QN(Entity.(entity_labels, target_fns, domains))
    g = get_graph(qn)

    @test haskey(g, EntityName(:c), EntityName(:a))
    @test haskey(g, EntityName(:a), EntityName(:b))
    @test haskey(g, EntityName(:b), EntityName(:c))
end

@testitem "QN Sampling" setup = [RandomSetup, ExampleQN] begin
    using Graphs: ne, nv
    graph = get_graph(qn)

    @test nv(graph) == qn_size
    @test ne(graph) > 0
end

@testitem "QN properties, fields" setup = [RandomSetup, ExampleQN] begin
    import GraphDynamicalSystems: EntityName
    using DynamicalSystemsBase: get_state, set_state!, step!

    set_state!(qn, :A, 1)

    @test length(entities(qn)) == qn_size

    @test length(target_functions(qn)) == qn_size

    @test all(get_state(qn) .<= maximum.(get_domain(qn)))

    @test get_state(qn, :A) == 1

    @test_throws r"max" set_state!(qn, :A, 6)
end

@testitem "Target Function" setup = [RandomSetup, ExampleQN] begin
    using DynamicalSystemsBase: step!, get_state, set_state!
    set_state!(qn, :A, 1)
    set_state!(qn, :B, 1)
    set_state!(qn, :C, 1)

    # All state values should be 1, so adding two of them == 2, etc.
    # The size of the test network is 3, so there should be A, B, C
    # as available entities to work with.
    @test interpret(:(A + B), qn) == 2
    @test interpret(:(A - B), qn) == 0
    set_state!(qn, :B, 2)
    @test interpret(:(A / B), qn) == 0.5
    @test interpret(:(A / 2), qn) == 0.5
    @test interpret(:(min(A, B)), qn) == 1
    @test interpret(:(max(A, B)), qn) == 2
    @test interpret(:(ceil(A / B)), qn) == 1
    @test interpret(:(floor(A / B)), qn) == 0
    @test_throws r"Unhandled" interpret(:(nonexistent_function(A)), qn)
end

@testitem "Async QN" setup = [RandomSetup] begin
    using DynamicalSystemsBase: step!, get_state, set_state!
    qn_size = 3
    max_eq_depth = 3

    for N = 2:5 # a few different levels of N
        for _ = 1:100 # 100 different initializations
            domains = [1:N for _ = 1:qn_size]
            async_qn = sample_qualitative_network(
                qn_size,
                domains,
                max_eq_depth;
                schedule = Asynchronous,
            )
            async_qn_system = create_qn_system(async_qn)
            step!(async_qn_system, 100)
            @test all(get_state(async_qn_system.model) .<= maximum.(domains))
        end
    end

end

@testitem "Get attractors" setup = [RandomSetup, ExampleQN] begin
    using Attractors: AttractorsViaRecurrences, basins_of_attraction
    qn_size = 3
    max_eq_depth = 3
    N = 3
    domains = [1:N for _ = 1:qn_size]

    async_qn =
        sample_qualitative_network(qn_size, domains, max_eq_depth; schedule = Asynchronous)
    async_qn_system = create_qn_system(async_qn)

    grid = Tuple(range(0, 1) for _ = 1:qn_size)

    mapper = AttractorsViaRecurrences(async_qn_system, grid)

    basins = basins_of_attraction(mapper, grid)
end
