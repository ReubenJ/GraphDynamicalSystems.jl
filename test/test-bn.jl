using MetaGraphsNext: nv, MetaGraph
using DynamicalSystemsBase: trajectory
using SoleLogics: cnf, AbstractSyntaxStructure, LeftmostLinearForm, ∧

@testset "Boolean Network Sampling" begin
    bn = BooleanNetworks.sample_boolean_network(10)
    @test nv(bn) == 10
    @test isa(bn, MetaGraph)

    bn_cnf = BooleanNetworks.sample_boolean_network(20; tactic = cnf)
    @test nv(bn_cnf) == 20
    @test typeof(bn_cnf[1]) <: LeftmostLinearForm{typeof(∧),<:AbstractSyntaxStructure}
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
