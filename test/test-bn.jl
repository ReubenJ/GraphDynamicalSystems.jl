using MetaGraphsNext: nv, MetaGraph
using DynamicalSystems: trajectory

@testset "Boolean Network Sampling" begin
    bn = BooleanNetworks.sample_boolean_network(10)
    @test nv(bn) == 10
    @test isa(bn, MetaGraph)
end

@testset "Boolean Network System Creation" begin
    bn = BooleanNetworks.sample_boolean_network(10)
    initial_state = rand(0:1, 10)
    abn = BooleanNetworks.abn(bn, deepcopy(initial_state))
    traj = trajectory(abn, 10)
    @test traj[1][1] == initial_state
    @test length(traj[1]) == 11
end
