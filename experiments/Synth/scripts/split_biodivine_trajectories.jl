#!/usr/bin/env -S julia --project=.
#
#SBATCH --job-name="Split"
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --ntasks 64
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

using JLD2
using ProgressMeter

trajectories_dir = datadir("sims", "biodivine_trajectories")
split_trajectories_dir = datadir("sims", "biodivine_split")

param_setup = Dict("traj_file" => readdir(datadir("sims", "biodivine_trajectories")))
all_params = dict_list(param_setup)

@showprogress pmap(all_params) do params
    @produce_or_load(
        params,
        path = split_trajectories_dir,
        filename = params["traj_file"]
    ) do params
        @unpack traj_file = params
        traj_file_contents = load(joinpath(trajectories_dir, traj_file))
        if "trajectories" in keys(traj_file_contents)
            trajectories = traj_file_contents["trajectories"] # also includes git tag, etc.

            split_traj = split_state_space.(trajectories)
            return @strdict split_traj
        else
            @info "No trajectory found for $traj_file"
        end
    end
end
