#!/bin/sh
#
#SBATCH --job-name="Synthesize Biodivine"
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=3G
#SBATCH --account=innovation

module load 2024r1 julia

srun julia -t 16 --project=. scripts/synth_biodivine.jl
