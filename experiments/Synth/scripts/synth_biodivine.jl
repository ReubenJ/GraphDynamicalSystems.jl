#!/usr/bin/env -S julia --project=.
#
#SBATCH --job-name="Synth"
#SBATCH --partition=compute
#SBATCH --time=72:00:00
#SBATCH --ntasks 256
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
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

@everywhere using ProgressMeter, DataFrames, HerbSearch, GraphDynamicalSystems

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
    "grammar_builder" => [build_dnf_grammar, build_qn_grammar],
    "max_iterations" => 1_000_000,
)

@showprogress pmap(dict_list(synth_params)) do params
    synth_one_biodivine(params, res)
end
