#!/usr/bin/env -S julia
#
#SBATCH --job-name="BBM"
#SBATCH --partition=compute
#SBATCH --time=00:15:00
#SBATCH --ntasks 32
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1G
#SBATCH --account=research-eemcs-st

using Distributed
try
    using SlurmClusterManager
    addprocs(SlurmManager())
catch
    @info "Not running from within Slurm, proceeding without Slurm workers"
end

@everywhere using DrWatson

@everywhere @quickactivate :Synth


@info "Cloning the biodivine benchmark repository"
bbm_dir = datadir("src_raw", "biodivine-boolean-models")
if !isdir(bbm_dir)
    get_biodivine_repo(bbm_dir)
end

@info "Bundling the benchmark to .aeon format"
aeon_bundle_dir = joinpath(bbm_dir, "bbm-aeon-format")
if !isdir(aeon_bundle_dir)
    bundle_biodivine_benchmark(bbm_dir, aeon_bundle_dir)
end

@info "Parsing .aeon model files"
ids_to_ignore = ["079"]
load_aeon_biodivine(bbm_dir, ids_to_ignore)

@info "Converting to MetaGraph-based models"
excluded_files = [r"041\.aeon\.jld2", r"079\.aeon\.jld2"]
convert_aeon_models_to_metagraphs(excluded_files)
