using DrWatson

@quickactivate :SynthBN

using DataFrames
using Herb, HerbGrammar, SoleLogics, HerbSpecification, HerbSearch
using Random
using Graphs: nv

include(srcdir("grammars.jl"))
include(srcdir("synth_process.jl"))
include(srcdir("evaluator.jl"))
include(srcdir("create_problem.jl"))

res = collect_results!(datadir("sims", "biodivine_split"))
res.ID = ((x -> x[end-1]["id"]) ∘ parse_savename).(res.path)
rename!(res, :path => "Trajectory Path")
mg_df = collect_results!(datadir("src_parsed", "biodivine_benchmark_as_metagraphs"))
mg_df.ID = ((x -> parse(Int, x)) ∘ (x -> x[1]) ∘ splitext ∘ basename).(mg_df.path)
rename!(mg_df, :path => "Model Path")

res = innerjoin(res, mg_df, on = :ID)

synth_params = Dict(
    "seed" => 42,
    "max_depth" => 6,
    "id" => res.ID,
    "n_trajectories" => collect(10:10:100),
    "iterator_type" => [BFSIterator],
    "grammar_builder" => [build_dnf_grammar],
    "max_iterations" => 5_000_000,
)

function synth_one_vertex(save_data)
    @unpack vertex, examples = save_data
    problem = examples_to_problem(vertex, examples)

    @unpack max_depth, iterator_type, max_iterations, grammar = save_data
    iterator = iterator_type(grammar, :Start, max_depth = max_depth)
    exprs_and_scores = synth_biodivine(problem, iterator, grammar, max_iterations)

    # Save output
    save_data["exprs_and_scores"] = exprs_and_scores
    return save_data
end

function synth_one_biodivine(outer_params::AbstractDict{String,Any}, res::DataFrame)
    params = deepcopy(outer_params)
    @unpack seed = params
    Random.seed!(seed)

    @unpack n_trajectories = params
    selected_trajs = rand(res.split_traj, n_trajectories)

    merged_selected_trajs = reduce(mergewith(union), selected_trajs)

    @unpack id, grammar_builder = params
    @info "Synthsizing for model $id with $n_trajectories traj."

    model = only(res[res.ID.==id, :metagraph_model])
    grammar = grammar_builder(nv(model))

    for (vertex, examples) ∈ merged_selected_trajs
        @info "Synthesizing model $id, node $vertex, $n_trajectories traj."
        save_data = deepcopy(params)
        delete!(save_data, "specifications")
        save_data["grammar"] = grammar
        save_data["vertex"] = vertex
        save_data["examples"] = examples
        file_name = savename(save_data)
        @produce_or_load(
            synth_one_vertex,
            save_data,
            datadir("exp_raw", "biodivine_search");
            filename = file_name
        )
        @info "Completed synthesis for model $id, node $vertex, $n_trajectories traj."
    end
end

Threads.@threads for params in dict_list(synth_params)
    synth_one_biodivine(params, res)
end
