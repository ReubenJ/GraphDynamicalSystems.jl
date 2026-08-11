@testitem "Construct" begin
    import QualitativeNetworks as QNs
    import GraphDynamicalSystems as GDS

    qn = QNs.QN([:x, :y, :z], Union{Symbol, Int, Expr}[:x, :x, :(y - x)], [0:2, 0:2, 0:2])

    @test length(GDS.vertices(qn)) == 3
    @test length(GDS.edges(qn)) == 4
    @test GDS.update_function(qn) == [:x, :x, :(y - x)]
    @test GDS.update_function(qn, [:z]) == [:(y - x)]
end

@testitem "Convert to SimpleDiGraph" begin
    import QualitativeNetworks as QNs
    import GraphDynamicalSystems as GDS
    import Graphs

    qn = QNs.QN([:x, :y, :z], Union{Symbol, Int, Expr}[:x, :x, :(y - x)], [0:2, 0:2, 0:2])
    graph = GDS.Conversions.to_simple_graph(qn)

    @test Graphs.nv(graph) == 3
    @test Graphs.ne(graph) == 4
end

@testitem "Convert to DynamicalSystem" begin
    import QualitativeNetworks as QNs
    import GraphDynamicalSystems as GDS
    import DynamicalSystemsBase as DSB
    import MetaGraphsNext as MG
    import Graphs
    using Attractors: AttractorsViaRecurrences, basins_of_attraction

    function qn_fn_wrapper(v, f, low, high)
        return function (state)
            previous_val = state[v]
            new_val = clamp(previous_val + sign(f(state) - previous_val), low, high)
            return round(Int, new_val)
        end
    end

    vs = [:x, :y, :z]
    fns = [
        qn_fn_wrapper(:x, _ -> 2, 0, 2),
        qn_fn_wrapper(:y, state -> state[:x], 0, 2),
        qn_fn_wrapper(:z, state -> state[:y] - state[:x], 0, 2),
    ]
    ds = [0:2, 0:2, 0:2]
    vd = QNs.VertexData.(fns, zeros(length(vs)), ds)
    es = Graphs.Edge.([(1, 1), (1, 2), (1, 3), (2, 3)])
    es_sym = [(:x, :x), (:x, :y), (:x, :z), (:y, :z)]
    graph = Graphs.SimpleDiGraph(es)
    meta_graph = MG.MetaGraph(graph, vs .=> vd, Tuple.(es_sym) .=> nothing)
    qn = QNs.QN(meta_graph)
    as = GDS.Conversions.to_arbitrary_steppable(qn)

    @test DSB.current_state(as) == [0, 0, 0]
    DSB.step!(as)
    @test DSB.current_state(as) == [1, 0, 0]

    grid = Tuple(range(0, 2) for _ in 1:3)

    mapper = AttractorsViaRecurrences(as, grid)

    basins = basins_of_attraction(mapper, grid)
    @test length(basins.attractors) == 1
    @test collect(keys(basins.attractors)) == [1]
    @test first(basins.attractors[1]) == [2, 2, 0]
end

@testitem "Convert to discrete system" begin
    @test_skip false
end

@testitem "Explicit imports" begin
    using ExplicitImports: test_explicit_imports
    test_explicit_imports(QualitativeNetworks)
end
