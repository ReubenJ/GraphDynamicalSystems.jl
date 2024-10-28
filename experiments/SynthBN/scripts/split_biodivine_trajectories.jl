"""
Takes the biodivine trajectories and divides them into i/o pairs for synthesis
"""

using DrWatson

@quickactivate :SynthBN

using JLD2

trajectories = datadir("sims", "biodivine_trajectories")
split_trajectories = datadir("sims", "biodivine_split")

for traj_file in readdir(datadir("sims", "biodivine_trajectories"); join = true)
    traj_path = joinpath(trajectories, traj_file)
    split_path = joinpath(split_trajectories, traj_file)

    if !isfile(split_path)
        @info "Splitting $traj_file..."
        load(traj_file) do traj_file_contents
            trajectories = traj_file_contents["trajectories"] # also includes git tag, etc.
            split_traj = split_state_space.(trajectories)
            @tagsave(split_path, @strdict split_traj)
        end
    else
        @info "$split_path already exists"
    end
end
