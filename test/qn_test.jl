@testsetup module RandomSetup
using Random: seed!
seed!(42)
end

@testsetup module ExampleQN
export qn_size, max_eq_depth, domains, qn
using GraphDynamicalSystems

qn_size = 3
max_eq_depth = 3
domains = [1:5, 1:5, 1:5]
qn = sample_qualitative_network(qn_size, domains, max_eq_depth)
end

@testitem "QN Grammar Creation" begin
    entities = [:a, :b, :c]
    constants = [i for i = 0:10]
    g = build_qn_grammar(entities, constants)

    @test issubset(Set(entities), Set(g.rules))
    @test issubset(Set(constants), Set(g.rules))
end

@testitem "QN Graph Correctness" begin
    import GraphDynamicalSystems: EntityName
    import MetaGraphsNext: edge_labels

    entity_labels = [:a, :b, :c]
    target_fns = Union{Expr,Integer,Symbol}[:(-c), :a, :b]
    domains = [0:2 for _ = 1:3]

    qn = QN(Entity.(entity_labels, target_fns, domains))
    g = get_graph(qn)

    @show collect(edge_labels(g))
    @test haskey(g, EntityName(:c), EntityName(:a))
    @test haskey(g, EntityName(:a), EntityName(:b))
    @test haskey(g, EntityName(:b), EntityName(:c))
end

@testitem "QN Sampling" setup = [RandomSetup, ExampleQN] begin
    using Graphs: ne, nv
    graph = get_graph(qn)

    @test nv(graph) == qn_size
    @test ne(graph) > 0
end

@testitem "QN properties, fields" setup = [RandomSetup, ExampleQN] begin
    import GraphDynamicalSystems: EntityName
    using DynamicalSystemsBase: get_state, set_state!, step!

    set_state!(qn, :A, 1)

    @test length(entities(qn)) == qn_size

    @test length(target_functions(qn)) == qn_size

    @test all(get_state(qn) .<= maximum.(get_domain(qn)))

    @test get_state(qn, :A) == 1

    @test_throws r"max" set_state!(qn, :A, 6)
end

@testitem "Target Function" setup = [RandomSetup, ExampleQN] begin
    using DynamicalSystemsBase: step!, get_state, set_state!
    set_state!(qn, :A, 1)
    set_state!(qn, :B, 1)
    set_state!(qn, :C, 1)

    # All state values should be 1, so adding two of them == 2, etc.
    # The size of the test network is 3, so there should be A, B, C
    # as available entities to work with.
    @test interpret(:(A + B), qn) == 2
    @test interpret(:(A - B), qn) == 0
    set_state!(qn, :B, 2)
    @test interpret(:(A / B), qn) == 0.5
    @test interpret(:(A / 2), qn) == 0.5
    @test interpret(:(min(A, B)), qn) == 1
    @test interpret(:(max(A, B)), qn) == 2
    @test interpret(:(ceil(A / B)), qn) == 1
    @test interpret(:(floor(A / B)), qn) == 0
    @test_throws r"Unhandled" interpret(:(nonexistent_function(A)), qn)
end

@testitem "Async QN" setup = [RandomSetup] begin
    using DynamicalSystemsBase: step!, get_state, set_state!
    qn_size = 3
    max_eq_depth = 3

    for N = 2:5 # a few different levels of N
        for _ = 1:100 # 100 different initializations
            domains = [1:N for _ = 1:qn_size]
            async_qn = sample_qualitative_network(
                qn_size,
                domains,
                max_eq_depth;
                schedule = Asynchronous,
            )
            async_qn_system = create_qn_system(async_qn)
            step!(async_qn_system, 100)
            @test all(get_state(async_qn_system.model) .<= maximum.(domains))
        end
    end

end

@testitem "Get attractors" setup = [RandomSetup, ExampleQN] begin
    using Attractors: AttractorsViaRecurrences, basins_of_attraction
    qn_size = 3
    max_eq_depth = 3
    N = 3
    domains = [1:N for _ = 1:qn_size]

    async_qn =
        sample_qualitative_network(qn_size, domains, max_eq_depth; schedule = Asynchronous)
    async_qn_system = create_qn_system(async_qn)

    grid = Tuple(range(0, 1) for _ = 1:qn_size)

    mapper = AttractorsViaRecurrences(async_qn_system, grid)

    basins = basins_of_attraction(mapper, grid)
end

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

@testitem "Load from BMA" setup = [RandomSetup] begin
    using DynamicalSystemsBase: step!
    bma_models_path = joinpath(@__DIR__, "resources", "bma_models")
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
    import GraphDynamicalSystems: is_default_function
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
            orig_f = Meta.parse(orig_v["Formula"])
            f = Meta.parse(v["Formula"])

            if is_default_function(orig_f, orig_v["RangeFrom"], orig_v["RangeTo"])
                @test isnothing(f)
            else
                @test orig_f == f
            end
        end
        orig_variables_no_f = [
            Dict(k => v for (k, v) in var if k != "Formula") for
            var in orig_dict["Model"]["Variables"]
        ]
        output_variables_no_f =
            [Dict(k => v for (k, v) in var if k != "Formula") for var in variables]
        @test orig_variables_no_f == output_variables_no_f

        @test haskey(model_dict, "Relationships")
        relationships = model_dict["Relationships"]
        orig_relationships_no_id = [
            Dict(k => v for (k, v) in rel if k != "Id") for
            rel in orig_dict["Model"]["Relationships"]
        ]
        output_relationships_no_id =
            [Dict(k => v for (k, v) in rel if k != "Id") for rel in relationships]
        @test Set(orig_relationships_no_id) == Set(output_relationships_no_id)
    end
    bma_models_path = joinpath(@__DIR__, "resources", "bma_models")
    good_models = joinpath(bma_models_path, "well_formed_examples")

    # just another reminder that the "Skin1D" example isn't working with this test
    @test_broken false

    for model_path in filter(!contains(r"Skin1D"), readdir(good_models; join = true))
        test_json_roundtrip(model_path)
    end
end

@testitem "is default function" begin
    import IterTools: subsets
    import GraphDynamicalSystems:
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
