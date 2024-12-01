using Graphs: ne, nv

@testset "QN Grammar Creation" begin
    entities = [:a, :b, :c]
    constants = [i for i = 1:10]
    g = QualitativeNetworks.build_qn_grammar(entities, constants)

    @test issubset(Set(entities), Set(g.rules))
    @test issubset(Set(constants), Set(g.rules))

    g2 = QualitativeNetworks.build_qn_grammar(Symbol[], Integer[])

    @test isempty(setdiff(Set(g2.rules), Set(entities)))
    @test isempty(setdiff(Set(g2.rules), Set(constants)))
end

@testset "QN Sampling" begin
    size = 3
    max_eq_depth = 3
    qn = QualitativeNetworks.sample_qualitative_network(size, max_eq_depth)
    @test nv(qn.graph) == size
    @test ne(qn.graph) > 0
end
