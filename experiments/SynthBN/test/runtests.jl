using DrWatson, Test
@quickactivate "SynthBN"

using HerbGrammar, HerbConstraints

# Here you include files using `srcdir`
include(srcdir("gather_bn_data.jl"))
include(srcdir("grammars.jl"))

# Run test suite
println("Starting tests")
ti = time()

@testset "SynthBN tests" begin
    @testset "State division smoke test" begin
        network_size = 10
        max_equation_depth = 3
        seed = 42
        iterations = 1000

        bn = sample_boolean_network(network_size, max_equation_depth, seed)
        async_bn = abn(bn; seed = seed)
        trajectory = gather_bn_data(async_bn, iterations)
        divided_state_space = split_state_space(trajectory)
    end

    @testset "Neighbor counting from RuleNode" begin
        dnf = build_dnf_grammar(3) # rules 8, 9, and 10 are terminal

        r₁ = RuleNode(1, [RuleNode(8), RuleNode(8)])    # just 1 neighbor, used twice
        r₂ = RuleNode(1, [RuleNode(8), RuleNode(9)])    # 2 neighbors
        r₃ = RuleNode(1)                                # no neighbors

        @test count_neighbors_in_expr(r₁, dnf) == 1
        @test count_neighbors_in_expr(r₂, dnf) == 2
        @test count_neighbors_in_expr(r₃, dnf) == 0

        rₛ = StateHole(
            HerbConstraints.StateSparseSet(HerbConstraints.StateManager(), 1),
            [RuleNode(8), RuleNode(9)],
        )
        @test count_neighbors_in_expr(rₛ, dnf) == 2
    end
end

ti = time() - ti
println("\nTest took total time of:")
println(round(ti / 60, digits = 3), " minutes")
