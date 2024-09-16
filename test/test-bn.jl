using MetaGraphsNext: nv, MetaGraph
using DynamicalSystems: trajectory

@testset "Boolean Network Sampling" begin
    bn = BooleanNetworks.sample_boolean_network(10)
    @test nv(bn) == 10
    @test isa(bn, MetaGraph)
end

@testset "Asynchronous Boolean Network Creation" begin

    @testset "with explicit initial state" begin
        bn = BooleanNetworks.sample_boolean_network(10)
        initial_state = rand(0:1, 10)
        abn = BooleanNetworks.abn(bn, deepcopy(initial_state))
        traj = trajectory(abn, 10)
        @test traj[1][1] == initial_state
        @test length(traj[1]) == 11
    end

    @testset "with random initial state" begin
        bn = BooleanNetworks.sample_boolean_network(10)
        abn₁ = BooleanNetworks.abn(bn; seed = 10)
        traj₁ = trajectory(abn₁, 10)
        abn₂ = BooleanNetworks.abn(bn; seed = 10)
        traj₂ = trajectory(abn₂, 10)
        @test traj₁[1] == traj₂[1]
    end
end
