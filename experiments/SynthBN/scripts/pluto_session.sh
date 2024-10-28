#!/bin/bash

#SBATCH --job-name=pluto
#SBATCH --partition=compute
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=1G
#SBATCH --account=innovation

# Load modules:
module load 2024r1
module load julia

julia --project=. -e 'using Pluto; Pluto.run(host="0.0.0.0", port=1234, launch_browser=false)' > pluto_output.txt
