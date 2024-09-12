using MetaGraphsNext: nv, MetaGraph

@testset "Boolean Network Sampling" begin
    bn = BooleanNetworks.sample_boolean_network(10)
    @test nv(bn) == 10
    @test isa(bn, MetaGraph)
end
