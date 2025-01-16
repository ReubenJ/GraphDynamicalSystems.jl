#!/usr/bin/env -S julia --project=.
#
#SBATCH --job-name="Synth"
#SBATCH --partition=compute
#SBATCH --time=24:00:00
#SBATCH --ntasks 512
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --account=research-eemcs-st

using Distributed
try
    using SlurmClusterManager
    addprocs(SlurmManager())
catch
    @info "Not running from within Slurm, proceeding without Slurm workers"
end

@everywhere using DrWatson

@everywhere quickactivate(pwd())
@everywhere using Synth

@everywhere begin
    using ProgressMeter
    using DataFrames
    using HerbGrammar, SoleLogics, HerbSpecification, HerbSearch
    using Random
    using Graphs: nv

    include(srcdir("grammars.jl"))
    include(srcdir("synth_process.jl"))
    include(srcdir("evaluator.jl"))
    include(srcdir("create_problem.jl"))
end

res = collect_results(datadir("sims", "biodivine_split"))
res.ID = ((x -> x[end-1]["id"]) ∘ parse_savename).(res.path)
rename!(res, :path => "Trajectory Path")
mg_df = collect_results(datadir("src_parsed", "biodivine_benchmark_as_metagraphs");)
mg_df.ID = ((x -> parse(Int, x)) ∘ (x -> x[1]) ∘ splitext ∘ basename).(mg_df.path)
rename!(mg_df, :path => "Model Path")

res = innerjoin(res, mg_df, on = :ID)

synth_params = Dict(
    "seed" => 42,
    "max_depth" => 6,
    "id" => res.ID,
    "n_trajectories" => collect(10:20:110),
    "iterator_type" => [BFSIterator],
    "grammar_builder" => [build_dnf_grammar],
    "max_iterations" => 1_000_000,
)

@everywhere function synth_one_vertex(save_data)
    @unpack vertex, examples = save_data
    problem = examples_to_problem(vertex, examples)

    @unpack max_depth, iterator_type, max_iterations, grammar = save_data
    iterator = iterator_type(grammar, :Start, max_depth = max_depth)
    exprs_and_scores = synth_biodivine(problem, iterator, grammar, max_iterations)

    # Save output
    save_data["exprs_and_scores"] = exprs_and_scores
    return save_data
end

@everywhere function synth_one_biodivine(
    outer_params::AbstractDict{String,Any},
    res::DataFrame,
)
    params = deepcopy(outer_params)
    @unpack seed = params
    Random.seed!(seed)

    @unpack n_trajectories, id = params
    selected_trajs = rand(only(res[res.ID.==id, :split_traj]), n_trajectories)

    merged_selected_trajs = reduce(mergewith(union), selected_trajs)

    @unpack id, grammar_builder = params
    @info "Synthsizing for model $id with $n_trajectories traj."

    model = only(res[res.ID.==id, :metagraph_model])
    grammar = grammar_builder(nv(model))

    @showprogress pmap(collect(merged_selected_trajs)) do (vertex, examples)
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

@showprogress pmap(dict_list(synth_params)) do params
    synth_one_biodivine(params, res)
end
