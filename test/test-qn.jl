using Graphs: ne, nv

@testset "QN Grammar Creation" begin
    entities = [:a, :b, :c]
    constants = [i for i = 1:10]
    g = QualitativeNetworks.build_qn_grammar(entities, constants)

    @test issubset(Set(entities), Set(g.rules))
    @test issubset(Set(constants), Set(g.rules))
end

@testset "QN Sampling" begin
    size = 3
    max_eq_depth = 3
    qn = QualitativeNetworks.sample_qualitative_network(size, max_eq_depth)
    @test nv(qn.graph) == size
    @test ne(qn.graph) > 0
end
