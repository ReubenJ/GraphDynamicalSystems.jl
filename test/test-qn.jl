using Attractors: AttractorsViaRecurrences, basins_of_attraction
using DynamicalSystemsBase: step!, get_state, set_state!
using Graphs: ne, nv
using Random: seed!

seed!(42)

@testset "QN Grammar Creation" begin
    entities = [:a, :b, :c]
    constants = [i for i = 1:10]
    g = build_qn_grammar(entities, constants)

    @test issubset(Set(entities), Set(g.rules))
    @test issubset(Set(constants), Set(g.rules))

    g2 = build_qn_grammar(Symbol[], Integer[])

    @test isempty(intersect(Set(g2.rules), Set(entities)))
    @test isempty(intersect(Set(g2.rules), Set(constants)))
end

size = 3
max_eq_depth = 3
N = 5
network = sample_qualitative_network(size, max_eq_depth)
initial_state = ones(size)
qn = QualitativeNetwork(network, initial_state, N)

@testset "QN Sampling" begin
    @test nv(network) == size
    @test ne(network) > 0
end

@testset "QN properties, fields" begin
    @test length(components(qn)) == size

    @test length(target_functions(qn)) == size

    @test all(get_state(qn) .<= max_level(qn))

    @test get_state(qn, components(qn)[1]) == 1

    @test_throws r"max" set_state!(qn, Symbol(1), 6)
end

@testset "QN Construction" begin
    basic_grammar = build_qn_grammar(Symbol[], Integer[])
    lower_N = 3
    initial_state_higher_than_N = [5, 5, 5]

    @test_throws r"<=" QN(basic_grammar, initial_state_higher_than_N, lower_N)
end

@testset "Target Function" begin
    # All state values should be 1, so adding two of them == 2, etc.
    # The size of the test network is 3, so there should be c1, c2, c3
    # as available components to work with.
    @test interpret(:(c1 + c2), qn) == 2
    @test interpret(:(c1 - c2), qn) == 0
    set_state!(qn, :c2, 2)
    @test interpret(:(c1 / c2), qn) == 0.5
    @test interpret(:(c1 / 2), qn) == 0.5
    @test interpret(:(Min(c1, c2)), qn) == 1
    @test interpret(:(Max(c1, c2)), qn) == 2
    @test interpret(:(Ceil(c1 / c2)), qn) == 1
    @test interpret(:(Floor(c1 / c2)), qn) == 0
    @test_throws r"Unhandled" interpret(:(nonexistent_function(c1)), qn)
end

@testset "Async QN" begin
    for N = 2:5 # a few different levels of N
        for _ = 1:100 # 100 different initializations
            async_qn = aqn(network, N)
            step!(async_qn, 100)
            @test all(get_state(async_qn.model) .<= N)
        end
    end

end

@testset "Get attractors" begin
    n_entities = 3
    qn = sample_qualitative_network(n_entities, 2)

    async_qn = aqn(qn, 1)

    grid = Tuple(range(0, 1) for _ = 1:n_entities)

    mapper = AttractorsViaRecurrences(async_qn, grid)

    basins = basins_of_attraction(mapper, grid)
end
