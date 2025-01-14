"""
Takes the biodivine trajectories and divides them into i/o pairs for synthesis
"""

using DrWatson

@quickactivate :Synth

using JLD2

trajectories_dir = datadir("sims", "biodivine_trajectories")
split_trajectories_dir = datadir("sims", "biodivine_split")

for traj_file in readdir(datadir("sims", "biodivine_trajectories"))
    traj_path = joinpath(trajectories_dir, traj_file)
    split_path = joinpath(split_trajectories_dir, traj_file)

    if !isfile(split_path)
        @info "Splitting $traj_file..."
        traj_file_contents = load(traj_path)
        if "trajectories" in keys(traj_file_contents)
            trajectories = traj_file_contents["trajectories"] # also includes git tag, etc.

            split_traj = split_state_space.(trajectories)
            @tagsave(split_path, @strdict split_traj)
        else
            @info "No trajectory found for $traj_file"
        end

    else
        @info "$split_path already exists"
    end
end
