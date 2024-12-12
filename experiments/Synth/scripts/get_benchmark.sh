#!/bin/sh
#
#SBATCH --job-name="Get Biodivine Benchmark"
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8G
#SBATCH --account=innovation

srun julia --project=. scripts/get_biodivine_benchmark.jl
