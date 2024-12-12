using Graphs: nv, ne

@testset "Load Stable Toy Model" begin
    res_path = joinpath(dirname(dirname(@__FILE__)), "bma_models")

    system = load_bma_file(joinpath(res_path, "ToyModelStable.json"))

    @test nv(system.model.graph) == 3
    @test ne(system.model.graph) == 3

    system = load_bma_file(joinpath(res_path, "VPC.json"))

    @test nv(system.model.graph) == 85
    @test ne(system.model.graph) == 140
end
