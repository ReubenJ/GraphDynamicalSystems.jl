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
