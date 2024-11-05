using Graphs: nv

@testset "Biodivine Pipeline" begin
    @kwdef struct ModelExpectedVals
        file::Any
        variables::Any
        regulations::Any
        inputs::Any
    end

    to_test = [
        ModelExpectedVals(file = "007.aeon", variables = 5, regulations = 14, inputs = 0),
        ModelExpectedVals(
            file = "001.aeon",
            variables = 302,
            regulations = 533,
            inputs = 19,
        ),
    ]

    for exp_vals in to_test
        @testset "$(exp_vals.file)" begin
            filepath = testdir(exp_vals.file)
            parsed_model = AEONParser.parse_aeon_file(filepath)
            update_functions::Vector{AEONParser.UpdateFunction} =
                filter(x -> x isa AEONParser.UpdateFunction, parsed_model)
            regulations::Vector{AEONParser.Regulation} =
                filter(x -> x isa AEONParser.Regulation, parsed_model)

            @testset "AEON Parsing" begin
                @test length(update_functions) == exp_vals.variables
                @test length(regulations) == exp_vals.regulations
            end

            mg = update_functions_to_network(update_functions, regulations)

            @testset "AEON to MG" begin
                @test nv(mg) == exp_vals.variables + exp_vals.inputs
            end

            @testset "Sample Trajectories" begin
                trajectories = []
                n_trajectories = 3
                trajectory_length = 25

                for i = 1:n_trajectories  # 3 trajectories
                    async_bn = BooleanNetworks.abn(mg, seed = i)
                    push!(trajectories, gather_bn_data(async_bn, trajectory_length))
                end

                @test length(trajectories) == n_trajectories
                @test all(length.(trajectories) .== trajectory_length + 1)
                @test dimension(trajectories[1]) == nv(mg)
            end
        end
    end
end
