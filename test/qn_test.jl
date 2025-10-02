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

@testitem "QN Sampling" setup = [RandomSetup, ExampleQN] begin
    using Graphs: ne, nv
    graph = get_graph(qn)

    @test nv(graph) == qn_size
    @test ne(graph) > 0
end

@testitem "QN properties, fields" setup = [RandomSetup, ExampleQN] begin
    using DynamicalSystemsBase: step!, get_state, set_state!

    set_state!(qn, :A, 1)

    @test length(entities(qn)) == qn_size

    @test length(target_functions(qn)) == qn_size

    @test all(get_state(qn) .<= maximum.(get_domain(qn)))

    @test get_state(qn, :A) == 1

    @test_throws r"max" set_state!(qn, :A, 6)
end

@testitem "QN Construction" setup = [RandomSetup, ExampleQN] begin
    initial_state_beyond_domain = [5, 5, 5]

    # @test_throws r"<=" set_state!(qn, en
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
    @test interpret(:(Min(A, B)), qn) == 1
    @test interpret(:(Max(A, B)), qn) == 2
    @test interpret(:(Ceil(A / B)), qn) == 1
    @test interpret(:(Floor(A / B)), qn) == 0
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

@testitem "Load from BMA" begin
    using JSON
    bma_models_path = joinpath(@__DIR__, "resources", "bma_models")
    good_models = joinpath(bma_models_path, "well_formed_examples")

    for model_path in readdir(good_models; join = true)
        qn = QN(model_path)
        @test qn isa GraphDynamicalSystem
    end

    bad_models = joinpath(bma_models_path, "error_examples")

    @test_throws "Neither alternative" QN(joinpath(bad_models, "bad_edge_key.json"))
    @test_throws "Failed to add" QN(joinpath(bad_models, "duplicate_entity_ids.json"))
    @test_throws "Error while constructing name for entity" QN(
        joinpath(bad_models, "multiple_incoming_edges_same_name.json"),
    )

end
