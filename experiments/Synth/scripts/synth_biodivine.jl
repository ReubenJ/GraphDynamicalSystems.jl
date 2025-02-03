#!/usr/bin/env -S julia --project=.
#
#SBATCH --job-name="Synth"
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --ntasks 256
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8G
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

@everywhere using ProgressMeter, DataFrames, HerbSearch, GraphDynamicalSystems, Random
using MetaGraphsNext: labels
using Statistics: quantile

traj_df = collect_results(datadir("sims", "biodivine_split"))
path2id = path -> parse_savename(path)[end-1]["id"]
traj_df.ID = path2id.(traj_df.path)

model_df = collect_results(datadir("src_parsed", "biodivine_benchmark_as_metagraphs");)
path2id = path -> parse(Int, splitext(basename(path))[1])
model_df.ID = path2id.(model_df.path)
model_df.vertex = collect.(labels.(model_df.metagraph_model))
# add a copy so that after flattening we have all of the vertices of a model in each row of df
model_df.vertices = model_df.vertex

# Filter out the largest 5% of models
# They are likely Booleanized multivalue models—have to check
n_verts_per_model = length.(model_df.vertices)
per_vertex_df =
    flatten(model_df[n_verts_per_model.<=quantile(n_verts_per_model, 0.95), :], :vertex)

grammars_df = model_df[!, [:ID, :vertices]]
grammars_df.dnf_grammar = build_dnf_grammar.(grammars_df.vertices)
grammars_df.qn_grammar = build_qn_grammar.(grammars_df.vertices)

get_evaluator = g -> Dict([:DNF => evaluate_bn, :QN => evaluate_qn])[g]

function get_grammar(unique, grammar_type)
    s = :unknown
    if grammar_type == :DNF
        s = :dnf_grammar
    elseif grammar_type == :QN
        s = :qn_grammar
    end

    return only(grammars_df[grammars_df.ID.==unique.ID, s])
end

function select_trajectories(df, N, id, vertex, seed)
    Random.seed!(seed)
    selected_trajectories = rand(only(df[df.ID.==id, :split_traj]), N)
    filtered_on_vertex =
        reduce(union, map(x -> get(x, vertex, Set()), selected_trajectories))

    return filtered_on_vertex
end

synth_params = Dict(
    "seed" => 42,
    "max_depth" => 7,
    "unique" => collect(eachrow(per_vertex_df[!, [:ID, :vertex, :vertices]])),
    "id" => Derived("unique", x -> x.ID),
    "vertex_names" => Derived("unique", x -> getfield.(x.vertices, :value)),
    "index_of_vertex" => Derived("unique", x -> findfirst(==(x.vertex), x.vertices)),
    "vertex" => Derived("unique", x -> string(x.vertex.value)),
    "n_trajectories" => collect(10:45:110),
    "selected_trajectories" => Derived(
        ["n_trajectories", "unique", "index_of_vertex", "seed"],
        (N, unique, index_of_vertex, seed) ->
            select_trajectories(traj_df, N, unique.ID, index_of_vertex, seed),
    ),
    "iterator_type" => [BFSIterator],
    "iter_name" => Derived("iterator_type", string),
    "grammar_type" => [:DNF, :QN],
    "grammar" => Derived(["unique", "grammar_type"], get_grammar),
    "evaluator" => Derived("grammar_type", get_evaluator),
    "max_iterations" => 1_000_000,
)

@showprogress pmap(dict_list(synth_params)) do params
    # loadfile = false so we don't load all results into memory of the main process
    @produce_or_load(
        synth_one_vertex,
        params,
        datadir("exp_raw", "biodivine_search"),
        loadfile = false
    )
end
