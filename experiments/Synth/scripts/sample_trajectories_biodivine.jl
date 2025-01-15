#!/usr/bin/env -S julia --project=.
#
#SBATCH --job-name="Trajectories"
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --ntasks 32
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

using DataFrames
using GraphDynamicalSystems: BooleanNetworks
using ProgressMeter
using MetaGraphsNext

mg_df = collect_results(datadir("src_parsed", "biodivine_benchmark_as_metagraphs"))
mg_df[!, :ID] = ((x -> x[1]) ∘ splitext ∘ basename).(mg_df.path)
mg_df_by_id = groupby(mg_df, :ID)

param_setup = Dict("id" => mg_df.ID, "n_trajectories" => 200, "iterations" => 1000)
all_params = dict_list(param_setup)

@showprogress pmap(all_params) do params
    @produce_or_load(params, path = datadir("sims", "biodivine_trajectories"),) do params
        @unpack id, n_trajectories, iterations = params
        bn = mg_df_by_id[(id,)].metagraph_model[1]
        trajectories = []
        for traj_i = 1:n_trajectories
            async_bn = BooleanNetworks.abn(bn; seed = traj_i)
            push!(trajectories, gather_bn_data(async_bn, iterations))
        end
        @strdict trajectories
    end
end
