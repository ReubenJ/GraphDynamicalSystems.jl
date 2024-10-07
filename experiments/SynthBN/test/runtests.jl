using DrWatson, Test
@quickactivate "SynthBN"

# Here you include files using `srcdir`
include(srcdir("gather_bn_data.jl"))

# Run test suite
println("Starting tests")
ti = time()

@testset "SynthBN tests" begin
    network_size = 10
    max_equation_depth = 3
    seed = 42
    iterations = 1000

    bn = sample_boolean_network(network_size, max_equation_depth, seed)
    async_bn = abn(bn; seed = seed)
    trajectory = gather_bn_data(async_bn, iterations)
    divided_state_space = split_state_space(trajectory)
    @show divided_state_space
    @test 1 == 1
end

ti = time() - ti
println("\nTest took total time of:")
println(round(ti / 60, digits = 3), " minutes")
