@testsetup module RandomSetup
using Random: seed!
seed!(42)
end

@testsetup module ExampleQN
export qn_size, qn_fns, qn_domains, qn, qn_entities
import GraphDynamicalSystems as GDS

qn_size = 3
qn_entities = [:X, :Y, :Z]
qn_fns = Dict(:X => 1, :Y => :X, :Z => :(Y - X))
qn_domains = Dict(e => 0:5 for e in qn_entities)
qn = GDS.QN(qn_fns, qn_domains)
end

@testitem "From a dictionary of functions" begin
    import Graphs
    import SciMLBase
    import GraphDynamicalSystems as GDS
    import DynamicalSystemsBase as DSB

    fns = Dict(:A => 1, :B => :A, :C => :(B - A))
    d = Dict(k => 0:3 for k in keys(fns))
    qn = GDS.QualitativeNetwork{Graphs.SimpleGraph}(fns, d)
    SciMLBase.step!(qn)
    @test DSB.current_state(qn) == [1, 0, 0]
    DSB.set_state!(qn, [1, 2, 3])
    @test DSB.current_state(qn) == [1, 2, 3]
    SciMLBase.step!(qn)
    @test DSB.current_state(qn) == [1, 1, 2]
    SciMLBase.step!(qn)
    @test DSB.current_state(qn) == [1, 1, 1]
    SciMLBase.step!(qn)
    @test DSB.current_state(qn) == [1, 1, 0]
end

@testitem "QN Graph Correctness" begin
    import GraphDynamicalSystems: QN, get_graph
    import MetaGraphsNext: edge_labels

    target_fns = Dict(:a => :(-c), :b => :a, :c => :b)
    domains = Dict(:a => 0:2, :b => 0:2, :c => 0:2)

    qn = QN(target_fns, domains)
    g = get_graph(qn)

    @test haskey(g, :c, :a)
    @test haskey(g, :a, :b)
    @test haskey(g, :b, :c)
end

@testitem "QN properties, fields" setup = [RandomSetup, ExampleQN] begin
    import GraphDynamicalSystems: entities, get_fn, get_domain
    using DynamicalSystemsBase:
        current_state,
        set_state!,
        step!,
        isinplace,
        dynamic_rule,
        current_parameters,
        current_time
    set_state!(qn, 1, :X)

    @test length(entities(qn)) == qn_size

    @test length(get_fn(qn)) == qn_size

    @test all(current_state(qn) .<= maximum.(get_domain(qn)))

    @test current_state(qn, :X) == 1

    @test_throws r"domain" set_state!(qn, 6, :X)
    @test isinplace(qn)
    @test dynamic_rule(qn) == get_fn(qn)
    @test current_parameters(qn) == ()
    @test current_time(qn) == 0
end

@testitem "Target Function" setup = [RandomSetup, ExampleQN] begin
    import GraphDynamicalSystems: interpret
    using DynamicalSystemsBase: set_state!
    set_state!(qn, 1, :X)
    set_state!(qn, 1, :Y)
    set_state!(qn, 1, :Z)

    # All state values should be 1, so adding two of them == 2, etc.
    # The size of the test network is 3, so there should be A, B, C
    # as available entities to work with.
    @test interpret(:(X + Y), qn) == 2
    @test interpret(:(X - Y), qn) == 0
    set_state!(qn, 2, :Y)
    @test interpret(:(X / Y), qn) == 0.5
    @test interpret(:(X / 2), qn) == 0.5
    @test interpret(:(min(X, Y)), qn) == 1
    @test interpret(:(max(X, Y)), qn) == 2
    @test interpret(:(ceil(X / Y)), qn) == 1
    @test interpret(:(floor(X / Y)), qn) == 0
    @test_throws r"Unhandled" interpret(:(nonexistent_function(A)), qn)
end

@testitem "Async QN" setup = [RandomSetup, ExampleQN] begin
    using DynamicalSystemsBase: step!, current_state, set_state!
    import GraphDynamicalSystems: Asynchronous, QN
    qn_size = 3
    max_eq_depth = 3

    for N = 2:5 # a few different levels of N
        for _ = 1:100 # 100 different initializations
            domains = Dict(e => 0:N for e in qn_entities)
            async_qn = QN(qn_fns, domains)
            step!(async_qn, 100)
            @test all(current_state(async_qn) .<= maximum.(values(domains)))
        end
    end

end

@testitem "Get attractors" setup = [RandomSetup, ExampleQN] begin
    import GraphDynamicalSystems: Asynchronous
    using Attractors: AttractorsViaRecurrences, basins_of_attraction

    grid = Tuple(range(0, 1) for _ = 1:qn_size)

    mapper = AttractorsViaRecurrences(qn, grid)

    basins = basins_of_attraction(mapper, grid)
end
