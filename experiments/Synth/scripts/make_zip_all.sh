#!/bin/bash

#SBATCH --job-name=makezipall
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --account=innovation

# Load modules:
module load 2024r1

zip -r /scratch/rjgardosreid/Synth_backup.zip data/
