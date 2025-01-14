using DrWatson, Test
@quickactivate :Synth

using HerbGrammar, HerbConstraints
using GraphDynamicalSystems: BooleanNetworks
using DynamicalSystems: StateSpaceSet
using JLD2

# Run test suite
println("Starting tests")
ti = time()

testdir = (x...) -> projectdir("test", x...)

@testset "Synth tests" begin
    # @testset "Sample Trajectories" begin
    #     @unpack model = load(joinpath(@__DIR__, "ex_model.jld2"))
    #     async_bn = BooleanNetworks.abn(model.graph)
    #     @test !isnothing(gather_bn_data(async_bn, 1))
    # end

    # include(testdir("test_neighbor_counting.jl"))
    include(testdir("test_biodivine_pipeline.jl"))
end

ti = time() - ti
println("\nTest took total time of:")
println(round(ti / 60, digits = 3), " minutes")
