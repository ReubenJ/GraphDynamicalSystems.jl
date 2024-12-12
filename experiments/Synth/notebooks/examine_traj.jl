### A Pluto.jl notebook ###
# v0.20.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try
            Base.loaded_modules[Base.PkgId(
                Base.UUID("6e696c72-6542-2067-7265-42206c756150"),
                "AbstractPlutoDingetjes",
            )].Bonds.initial_value
        catch
            b -> missing
        end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 172d1c64-9528-11ef-1455-69f3dc33e1c4
using DrWatson

# ╔═╡ 49710c05-a20a-473f-9569-0579a35b8093
@quickactivate

# ╔═╡ 1d98adb9-5beb-476c-84db-5e6ccaf8841b
using DataFrames

# ╔═╡ a65b8474-8d7c-423a-9700-fda5a13e3622
using JLD2

# ╔═╡ 15b53ea1-57cb-45a6-9f15-e18bd9b8df29
using DynamicalSystems

# ╔═╡ 7f760eb1-a3ab-4599-8d24-58696e67c36d
using Plots

# ╔═╡ 77d6b0bc-cd28-46ed-b2f5-56eb94efc659
using PlutoUI

# ╔═╡ 6b843080-264a-4e30-a1fb-d05fb77ae526
function split_state_space(trajectory::StateSpaceSet)
    # split into pairs of input (all values) and output (changed value)
    input_output_pairs_per_node = Dict{Int,Set{Tuple{Vector{Int},Int}}}()
    for i = 1:length(trajectory)-1
        changed = findfirst(trajectory[i+1] .!= trajectory[i])
        # only proceed if there was a change
        if !isnothing(changed)

            # in real data we don't know the direction of the transition
            # was it from i -> i+1 or i+1 -> i, we only know that two
            # states are adjacent, so for gathering data, we add both
            # directions as IO pairs
            #   1. state `i` and the new value of the single variable in
            #      the state that changed
            #   2. state `i+1` and the previous value of the single variable
            #      in the state that changed

            new_value = trajectory[i+1][changed]
            old_value = trajectory[i][changed]
            existing_pairs =
                get(input_output_pairs_per_node, changed, Set{Tuple{Vector{Int},Int}}())
            push!(
                existing_pairs,
                (trajectory[i], new_value),     # 1
                (trajectory[i+1], old_value),   # 2
            )
            input_output_pairs_per_node[changed] = existing_pairs
        end
    end

    return input_output_pairs_per_node
end

# ╔═╡ 85379de4-3258-4471-b43c-75c65aea0b10
fname = "id=189_iterations=1000_n_trajectories=1000.jld2"

# ╔═╡ f2c8a3fa-61b5-4f39-b5f6-3329eba23ede
pname = joinpath(datadir("sims", "biodivine_trajectories"), fname)

# ╔═╡ 59dafbbe-086d-4fe6-b01c-e13ab8dc7d80
res = load(pname)

# ╔═╡ 1ce04619-14b1-4a4b-bc65-40dfdcae2c74
anim = @animate for i in eachindex(res["trajectories"])
    heatmap(Matrix(res["trajectories"][i]))
end

# ╔═╡ b36271d5-f908-4e65-b0fa-9175e8c2416c
# gif(anim)

# ╔═╡ 436fc3d5-fbf5-46b4-a6fd-3f8c97a00a47
traj = res["trajectories"]

# ╔═╡ 25966e19-4f35-4b3e-b60a-238cc182fbc9
@bind ind Slider(1:1000)

# ╔═╡ de871eaa-0991-4b3d-8c81-fd8afb284df7
heatmap(Matrix(res["trajectories"][ind]))

# ╔═╡ fe295564-151a-4325-9c4a-f47963ede398
split_applied = [split_state_space(t) for t in traj]

# ╔═╡ 17f352fc-6f4e-4d7d-ad7a-d6d2ac049ada
begin
    name = tempname()
    name *= ".jld2"
    save(name, @strdict split_applied)
end

# ╔═╡ 947a965d-54f5-40e3-b703-4a18bf671d9c
filesize(name) * 1e-6

# ╔═╡ 3c443200-79f9-4288-8989-6c06408240d5
filesize(pname) * 1e-6

# ╔═╡ 5ca0375d-d325-4831-85c4-17e871dc5a8b
name

# ╔═╡ Cell order:
# ╠═172d1c64-9528-11ef-1455-69f3dc33e1c4
# ╠═49710c05-a20a-473f-9569-0579a35b8093
# ╠═1d98adb9-5beb-476c-84db-5e6ccaf8841b
# ╠═a65b8474-8d7c-423a-9700-fda5a13e3622
# ╠═15b53ea1-57cb-45a6-9f15-e18bd9b8df29
# ╠═7f760eb1-a3ab-4599-8d24-58696e67c36d
# ╠═6b843080-264a-4e30-a1fb-d05fb77ae526
# ╠═85379de4-3258-4471-b43c-75c65aea0b10
# ╠═f2c8a3fa-61b5-4f39-b5f6-3329eba23ede
# ╠═59dafbbe-086d-4fe6-b01c-e13ab8dc7d80
# ╠═1ce04619-14b1-4a4b-bc65-40dfdcae2c74
# ╠═b36271d5-f908-4e65-b0fa-9175e8c2416c
# ╠═436fc3d5-fbf5-46b4-a6fd-3f8c97a00a47
# ╠═77d6b0bc-cd28-46ed-b2f5-56eb94efc659
# ╠═25966e19-4f35-4b3e-b60a-238cc182fbc9
# ╠═de871eaa-0991-4b3d-8c81-fd8afb284df7
# ╠═fe295564-151a-4325-9c4a-f47963ede398
# ╠═17f352fc-6f4e-4d7d-ad7a-d6d2ac049ada
# ╠═947a965d-54f5-40e3-b703-4a18bf671d9c
# ╠═3c443200-79f9-4288-8989-6c06408240d5
# ╠═5ca0375d-d325-4831-85c4-17e871dc5a8b
