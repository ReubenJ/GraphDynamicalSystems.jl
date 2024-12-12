#!/bin/sh
#
#SBATCH --job-name="Sample Trajectories"
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8G
#SBATCH --account=innovation

srun julia --project=. scripts/sample_trajectories_biodivine.jl
