### A Pluto.jl notebook ###
# v0.20.1

using Markdown
using InteractiveUtils

# ╔═╡ 1575b3cc-b786-11ef-34ef-dd6f58044fcc
using DrWatson

# ╔═╡ 0306d9f3-c210-4236-b9db-9ecb29787f08
@quickactivate

# ╔═╡ 8579e700-ef01-4ab9-a117-21bbf559d3dd
using GraphRecipes, Plots, DataFrames, Random, GraphDynamicalSystems, Graphs, MetaGraphsNext

# ╔═╡ 63b200cc-ae46-468e-ab25-e6d6ab58874b
using DynamicalSystems: Attractors, trajectory, StateSpaceSets

# ╔═╡ 90852030-deae-43d3-a573-124749d19d44
md"""
# Synthesizing Graph Dynamical Systems

PONY Lab Group Meeting, 11/12/2024
"""

# ╔═╡ 04361d06-11c1-468a-a97d-04a41b5d606a
md"""
## What's a GDS?

A model represented by

- A graph
- Each vertex in the graph has a function
- Edges in the graph denote which vertices are inputs to others
- Each vertex has a state
- Dynamics of the system depend on
  - Vertices' functions
  - The order you update them (_schedule_)
"""

# ╔═╡ 4a95f701-cf79-4800-aa5a-72c6ee4c2e13
md"""
## Example GDS: Boolean Network
"""

# ╔═╡ e59b989c-2e88-4063-88d0-a2a4e3aae567
md"""
## Why do we care about them?

- Executable models for bio, for example
- Can use to study the effect of a drug on a biological system

![BMA](https://github.com/user-attachments/assets/486bd9a9-a2a9-4dd3-8b55-00f7c8f1462a)
"""

# ╔═╡ c01be032-ec3f-4b7b-9698-90c7555cac50
md"""
## Why synthesize?

- Constructing by hand is time consuming
- Basically amounts to guess-and-check

To understand how we synthesize, let's return to our example network. What kind of information can we extract from it?
"""

# ╔═╡ 2092c9f8-515e-4674-ad76-fdb2f22c0439
md"""
## Data from our BN

State space/single cell measurements
"""

# ╔═╡ 9d09bc34-043c-4793-96f6-c7db927fed42
md"""
Steady state/mutation experiments
"""

# ╔═╡ 124b39da-e8a7-45d0-9a67-82dd08d16672
md"""
## Types of Schedules

- **Asynchronous**
  - Choose a vertex at random from the network
  - Run its function to update its value
- Synchronous
  - Run all vertices' functions to update their values
- Bounded Asynchrony
  - Run subsets of the vertices at the same time
  - Tricky case, probably will ignore this for today
"""

# ╔═╡ b608b534-4753-4529-8852-089aff34fab9
md"""
## Async BN

The `dynamic rule` is the asynchronous schedule mentioned before.
"""

# ╔═╡ aab65a05-e256-4140-ae83-6547985e01a2
md"""
## State Space
"""

# ╔═╡ 04ed17cb-69bd-48eb-b294-af120fe26b19
mg = MetaGraph(SimpleDiGraph(), label_type = String)

# ╔═╡ 8955d1d1-3cd0-4691-9c7f-f6179cc6e048
md"""
## Steady State(s)
"""

# ╔═╡ bf0a7add-f668-4fcc-87d4-ad535bf93b12
md"""
## Synthesizing

From the two types of data, two kinds of specifications:
- State space specifies how a specific vertex's function should transform the state
- Steady state specifies how a collection of vertex functions should behave

Refering to these as _local_ and _global_ constraints.
"""

# ╔═╡ 80136458-da57-4ea9-943c-bd6692fad780
md"""
## "Global" Constraint

> The steady state of the model is `[1, 0, 0, 1, 1]`

This is a constraint on the steady state of the model when combining synthesized functions for all vertices.
"""

# ╔═╡ 606d1e0e-ee79-4b12-964a-c5d597508761
md"""
## Discussion Question #1

If an incorrect steady-state is reached, which vertex is to blame?
"""

# ╔═╡ 1f02a380-2f17-44d2-a0a7-e4f7f3974c4c
begin
    mg2 = deepcopy(mg)
    bad_v = string([1, 0, 1, 1, 1])
    add_vertex!(mg2, bad_v)
    add_edge!(mg2, string([1, 0, 0, 1, 1]), bad_v)
    plot(
        mg2.graph;
        names = mg2.vertex_labels,
        nodesize = 0.06,
        nodecolor = [:lightblue, :lightblue, :lightblue, :red],
    )
end

# ╔═╡ a1759c77-2ff3-4722-a65c-25ecf50ac279
md"""
## Discussion Question #2

Assuming a synchronous schedule, how can we reconstruct the state space like we saw before?
"""

# ╔═╡ 8a243870-3d53-4312-b4d5-056f2372eb68
md"""
## Extras
"""

# ╔═╡ 5879d4f1-6bba-4675-b34b-9a1fcc023441
seed = 42

# ╔═╡ a217cd51-8c4b-4e74-90d3-b8d22daa6d62
Random.seed!(seed)

# ╔═╡ 964fca0e-b28d-4ebd-a2ad-3daf2ba2d4cd
network = BooleanNetworks.sample_boolean_network(5, 3, seed)

# ╔═╡ 452fda7d-e2f7-4162-a3d3-eef13ff3bdfc
plot(network.graph; names = network.vertex_labels, nodesize = 0.2)

# ╔═╡ 230f34b5-c160-4f06-b560-8306ae62e51e
[(k => v[2]) for (k, v) in network.vertex_properties]

# ╔═╡ d207a020-97e1-40ab-8f9b-8503cca9acf3
plot(network.graph; names = network.vertex_labels, nodesize = 0.2)

# ╔═╡ 51c331eb-77ef-4fcb-afff-c62fbf77d398
async_bn = BooleanNetworks.abn(network)

# ╔═╡ 6811c128-1aff-48e6-8af6-6946ebf7e6c1
trjs = [trajectory(async_bn, 100) for _ = 1:1000]

# ╔═╡ a52b6f33-bd36-4dae-9e90-4201e30bab78
trjs[1][1][1:5]

# ╔═╡ 8aeb938e-8cd2-4f0c-9bfc-9b35457b4e5d
trjs[1]

# ╔═╡ a16f15fe-491d-43a4-b41f-5e3b82c0ec85
ssp = begin
    for t in trjs
        for (f, s) in zip(t[1][1:end-1], t[1][2:end])
            add_vertex!(mg, string(f))
            add_vertex!(mg, string(s))
            add_edge!(mg, string(f), string(s))
        end
    end
    plot(mg.graph; names = mg.vertex_labels, nodesize = 0.05)
end

# ╔═╡ d7a3067a-5b81-4409-bcf7-0254bcd591fb
ssp

# ╔═╡ 8d39c39f-0897-43e8-942a-9a7884eb1dd4
ssp

# ╔═╡ 320ce9dc-5390-42eb-9b09-3e73f1bdd28b
attr = begin
    grid = Tuple(range(0, 1) for _ = 1:5)
    mapper = Attractors.AttractorsViaRecurrences(async_bn, grid)
    for _ = 1:1000
        mapper(rand(0:1, 5))
    end
    Attractors.extract_attractors(mapper)
end

# ╔═╡ e99505e5-6697-42c5-b763-77e5ee3d0158
attr[1]

# ╔═╡ 743cb689-469e-48f1-82cc-f7e2abeadf9a
md"""
## Local Constraint

> In: `[1, 0, 0, 1, 1]`, out: `[1, 0, 0, 0, 1]`

This is a constraint on vertex `4`'s update function.

A satisfying function would be $(string(network.vertex_properties[4][2])[26:end])
"""

# ╔═╡ Cell order:
# ╟─90852030-deae-43d3-a573-124749d19d44
# ╟─04361d06-11c1-468a-a97d-04a41b5d606a
# ╟─4a95f701-cf79-4800-aa5a-72c6ee4c2e13
# ╟─452fda7d-e2f7-4162-a3d3-eef13ff3bdfc
# ╟─230f34b5-c160-4f06-b560-8306ae62e51e
# ╟─e59b989c-2e88-4063-88d0-a2a4e3aae567
# ╟─c01be032-ec3f-4b7b-9698-90c7555cac50
# ╟─d207a020-97e1-40ab-8f9b-8503cca9acf3
# ╟─2092c9f8-515e-4674-ad76-fdb2f22c0439
# ╟─a52b6f33-bd36-4dae-9e90-4201e30bab78
# ╟─9d09bc34-043c-4793-96f6-c7db927fed42
# ╟─e99505e5-6697-42c5-b763-77e5ee3d0158
# ╟─124b39da-e8a7-45d0-9a67-82dd08d16672
# ╟─b608b534-4753-4529-8852-089aff34fab9
# ╠═51c331eb-77ef-4fcb-afff-c62fbf77d398
# ╟─aab65a05-e256-4140-ae83-6547985e01a2
# ╟─6811c128-1aff-48e6-8af6-6946ebf7e6c1
# ╠═8aeb938e-8cd2-4f0c-9bfc-9b35457b4e5d
# ╠═04ed17cb-69bd-48eb-b294-af120fe26b19
# ╟─a16f15fe-491d-43a4-b41f-5e3b82c0ec85
# ╟─8955d1d1-3cd0-4691-9c7f-f6179cc6e048
# ╟─320ce9dc-5390-42eb-9b09-3e73f1bdd28b
# ╟─d7a3067a-5b81-4409-bcf7-0254bcd591fb
# ╟─bf0a7add-f668-4fcc-87d4-ad535bf93b12
# ╟─743cb689-469e-48f1-82cc-f7e2abeadf9a
# ╟─80136458-da57-4ea9-943c-bd6692fad780
# ╟─606d1e0e-ee79-4b12-964a-c5d597508761
# ╟─1f02a380-2f17-44d2-a0a7-e4f7f3974c4c
# ╟─a1759c77-2ff3-4722-a65c-25ecf50ac279
# ╟─8d39c39f-0897-43e8-942a-9a7884eb1dd4
# ╟─8a243870-3d53-4312-b4d5-056f2372eb68
# ╠═1575b3cc-b786-11ef-34ef-dd6f58044fcc
# ╠═0306d9f3-c210-4236-b9db-9ecb29787f08
# ╠═a217cd51-8c4b-4e74-90d3-b8d22daa6d62
# ╠═5879d4f1-6bba-4675-b34b-9a1fcc023441
# ╠═964fca0e-b28d-4ebd-a2ad-3daf2ba2d4cd
# ╠═8579e700-ef01-4ab9-a117-21bbf559d3dd
# ╠═63b200cc-ae46-468e-ab25-e6d6ab58874b
