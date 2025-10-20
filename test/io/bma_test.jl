@testitem "Construct default target functions" begin
    lower_bound = 0
    upper_bound = 4
    activators = [:A, :B, :C]
    inhibitors = [:D, :E, :F]

    @test default_target_function(lower_bound, upper_bound, activators, inhibitors) ==
          :(max($lower_bound, (A + B + C) / 3 - (D + E + F) / 3))

    activators = [:A, :B]
    inhibitors = [:D]

    @test default_target_function(lower_bound, upper_bound, activators, inhibitors) ==
          :(max($lower_bound, (A + B) / 2 - D))

    activators = []
    inhibitors = [:D]

    @test default_target_function(lower_bound, upper_bound, activators, inhibitors) ==
          :($upper_bound - D)

    activators = [:A]
    inhibitors = []

    @test default_target_function(lower_bound, upper_bound, activators, inhibitors) == :(A)

    @test_throws r"no activators or inhibitors" default_target_function(0, 4)
end

@testitem "Load from BMA" begin
    using DynamicalSystemsBase: step!
    bma_models_path = joinpath(@__DIR__, "..", "resources", "bma_models")
    good_models = joinpath(bma_models_path, "well_formed_examples")

    for model_path in readdir(good_models; join = true)
        if occursin("Skin1D", model_path)
            @test_broken QN(model_path) isa GraphDynamicalSystem
        else
            qn = QN(model_path)
            @test qn isa GraphDynamicalSystem
            step!(create_qn_system(qn), 100)
        end
    end

    bad_models = joinpath(bma_models_path, "error_examples")

    @test_throws "Failed to add" QN(joinpath(bad_models, "duplicate_entity_ids.json"))
    @test_throws "Error while constructing name for entity" QN(
        joinpath(bad_models, "multiple_incoming_edges_same_name.json"),
    )
end

@testitem "Save to BMA" begin
    import MetaGraphsNext: edge_labels, labels
    import GraphDynamicalSystems.BMA: is_default_function
    using JSON

    function test_json_roundtrip(model_path::AbstractString)
        qn = QN(model_path)
        @test length(labels(get_graph(qn))) > 0
        @test length(edge_labels(get_graph(qn))) > 0

        output_str = JSON.json(qn)
        output_dict = JSON.parse(output_str)
        orig_dict = JSON.parse(read(model_path, String))

        if !haskey(orig_dict, "Model")
            @warn "Skipping test for file $model_path for now because of the nonstandard key names"
            return
        end

        @test haskey(output_dict, "Model")

        model_dict = output_dict["Model"]

        @test haskey(model_dict, "Variables")
        variables = model_dict["Variables"]
        for (orig_v, v) in zip(orig_dict["Model"]["Variables"], variables)
            if v["Name"] == ""
                @test !haskey(orig_v, "Name")
            else
                @test v["Name"] == orig_v["Name"]
            end
            orig_f = Meta.parse(orig_v["Formula"])
            f = Meta.parse(v["Formula"])

            if is_default_function(orig_f, orig_v["RangeFrom"], orig_v["RangeTo"])
                @test isnothing(f)
            else
                @test orig_f == f
            end
        end
        orig_variables_no_f = [
            Dict(k => v for (k, v) in var if k != "Formula" && k != "Name") for
            var in orig_dict["Model"]["Variables"]
        ]
        output_variables_no_f = [
            Dict(k => v for (k, v) in var if k != "Formula" && k != "Name") for
            var in variables
        ]
        @test orig_variables_no_f == output_variables_no_f

        @test haskey(model_dict, "Relationships")
        relationships = model_dict["Relationships"]
        orig_relationships_no_id = [
            Dict(k => v for (k, v) in rel if k != "Id") for
            rel in orig_dict["Model"]["Relationships"]
        ]
        output_relationships_no_id =
            [Dict(k => v for (k, v) in rel if k != "Id") for rel in relationships]

        # At least check that we are not creating new relationships out of nothing
        @test length(setdiff(output_relationships_no_id, orig_relationships_no_id)) == 0

        if occursin("VPC.json", model_path)
            @test_broken false # VPC has some weird relationships that are not used in the target functions
        else
            @test Set(orig_relationships_no_id) == Set(output_relationships_no_id)
        end
    end
    bma_models_path = joinpath(@__DIR__, "..", "resources", "bma_models")
    good_models = joinpath(bma_models_path, "well_formed_examples")

    # just another reminder that the "Skin1D" example isn't working with this test
    @test_broken false

    for model_path in filter(!contains(r"Skin1D"), readdir(good_models; join = true))
        test_json_roundtrip(model_path)
    end
end

@testitem "is default function" begin
    import IterTools: subsets
    import GraphDynamicalSystems.BMA:
        is_default_function, default_target_function, swap_entity_names_to_var_ids
    combinations = Iterators.filter(
        x -> !all(isempty.(x)),
        Iterators.product(subsets([:A_1, :B_2, :X_5, :Y_6]), subsets([:C_3, :D_4, :Z_7])),
    )
    activators = first.(combinations)
    inhibitors = last.(combinations)

    fns = default_target_function.(0, 4, activators, inhibitors)
    for f in swap_entity_names_to_var_ids.(fns)
        @test is_default_function(f, 0, 4)
    end
end
