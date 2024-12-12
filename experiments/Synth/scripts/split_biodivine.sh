#!/bin/sh
#
#SBATCH --job-name="Splitting Trajectories"
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8G
#SBATCH --account=innovation

module load 2024r1 julia

srun julia --project=. scripts/split_biodivine_trajectories.jl > splitting_trajectories.log
