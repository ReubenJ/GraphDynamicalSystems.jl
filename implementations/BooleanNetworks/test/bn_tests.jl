@testitem "Construct" begin
    import BooleanNetworks as BNs
    import GraphDynamicalSystems as GDS

    bn = BNs.BN{GDS.Asynchronous}([:x, :y, :z], Union{Symbol, Int, Expr}[:x, :x, :(y & ~x)])

    @test length(GDS.vertices(bn)) == 3
    @test length(GDS.edges(bn)) == 4
    @test GDS.update_function(bn) == [:x, :x, :(y & ~x)]
    @test GDS.update_function(bn, [:z]) == [:(y & ~x)]
end

@testitem "Convert to SimpleDiGraph" begin
    import BooleanNetworks as BNs
    import GraphDynamicalSystems as GDS
    import Graphs

    bn = BNs.BN{GDS.Asynchronous}([:x, :y, :z], Union{Symbol, Int, Expr}[:x, :x, :(y & ~x)])
    graph = GDS.Conversions.to_simple_graph(bn)

    @test Graphs.nv(graph) == 3
    @test Graphs.ne(graph) == 4
end

@testitem "Convert to DynamicalSystem" begin
    import BooleanNetworks as BNs
    import GraphDynamicalSystems as GDS
    import DynamicalSystemsBase as DSB
    import MetaGraphsNext as MG
    import Graphs
    using Attractors: AttractorsViaRecurrences, basins_of_attraction

    vs = [:x, :y, :z]
    fns = [
        _ -> true,
        state -> state[:x],
        state -> state[:y] & ~state[:x],
    ]
    vd = BNs.VertexData.(fns, zeros(length(vs)))
    es = Graphs.Edge.([(1, 1), (1, 2), (1, 3), (2, 3)])
    es_sym = [(:x, :x), (:x, :y), (:x, :z), (:y, :z)]
    graph = Graphs.SimpleDiGraph(es)
    meta_graph = MG.MetaGraph(graph, vs .=> vd, Tuple.(es_sym) .=> nothing)
    bn = BNs.BooleanNetwork{GDS.Asynchronous, typeof(meta_graph)}(meta_graph)
    as = GDS.Conversions.to_arbitrary_steppable(bn)

    @test DSB.current_state(as) == [0, 0, 0]

    grid = Tuple(range(0, 1) for _ in 1:3)

    mapper = AttractorsViaRecurrences(as, grid)

    basins = basins_of_attraction(mapper, grid)
    @test length(basins.attractors) == 1
    @test collect(keys(basins.attractors)) == [1]
    @test first(basins.attractors[1]) == [1, 1, 0]
end

@testitem "Convert to discrete system" begin
    @test_skip false
end

@testitem "Explicit imports" begin
    using ExplicitImports: test_explicit_imports
    test_explicit_imports(BooleanNetworks)
end
