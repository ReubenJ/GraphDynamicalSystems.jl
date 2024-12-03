using Graphs: ne, nv
using GraphDynamicalSystems
using HerbCore

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
    for (component, (index, target_fn)) in T(qn)
        @test depth(target_fn) <= max_eq_depth
    end
end

@testset "QN properties, fields" begin
    @test length(components(qn)) == size
    @test length(C(qn)) == size

    @test length(target_functions(qn)) == size
    @test length(T(qn)) == size

    @test all(get_state(qn) .<= max_level(qn))

    @test_throws r"max" set_state!(qn, Symbol(1), 6)
end

@testset "Target Function" begin

end
