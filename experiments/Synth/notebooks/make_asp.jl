### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ b402713a-02a9-11f0-1bca-69b96cd9c786
using DrWatson

# ╔═╡ ca420cdc-208a-4341-8409-b2e826dcf9d7
begin
    quickactivate(pwd())
    using Synth
    using ProgressMeter, DataFrames, HerbSearch, GraphDynamicalSystems, Random
    using MetaGraphsNext: labels
    using Statistics: quantile
    using DynamicalSystems
    using Clingo_jll
    using Plots
    using Graphs
    using GraphRecipes
end

# ╔═╡ df97a629-608b-45d0-815d-0a6c1d37d95c
using PlutoUI

# ╔═╡ f09edd39-ffeb-4850-b29e-b38565273ff5
md"""
## Creating an ASP Model for the Local Solution Assignment Problem

As input to the problem, we need to define the following ingredients:

- `entity(...).`
- `state(...).`
- `solution(...).`
- `steady(...).`

as well as mappings between ingredients:

- `belongs_to(solution, entity).`
- `connects(solution, state, state).`

### Entity Definitions

The `entity` definition is easy. Just a list of the entities.
"""

# ╔═╡ 701cca9d-f8de-4160-8f5d-c1ce30d31525
md"""
### State Definitions

For the local synthesis problems, we select a set of trajectories to synthesize from. The result of the local synthesis problem gives us information about which candidate solution connects which pairs of adjacent states.
"""

# ╔═╡ 690734ed-bdbf-4635-a4d2-37500fcea3cf
md"""
### Solution Definitions

Currently, we are storing the candidate solutions (expressions) and their scores in a 4-tuple:

> `(expression, score, per-transition-success, id)`

We extract the ID, and create a unique ID for the solution by prepending the candidate name.
"""

# ╔═╡ 51f9d1b9-304e-417f-9925-b572a90e278e
md"""
!!! warning
	I'm currently pruning too much, so this is not working. Solving for an assignment is still fast (<1s) so for now this doesn't matter.
"""

# ╔═╡ f298831c-8954-4957-a2b9-92f7b0cf9ca7
md"""
### Steady States

To mark which states are steady, we need to load the original Boolean Network model and extract them.
"""

# ╔═╡ b8265bb9-83d4-4bfd-9480-a9b55d78495e
begin
    model_df = collect_results(datadir("src_parsed", "biodivine_benchmark_as_metagraphs");)
    path2id = path -> parse(Int, splitext(basename(path))[1])
    model_df.ID = path2id.(model_df.path)
end

# ╔═╡ 437a480c-e63d-40f2-9d01-dd95275a333c
@assert model_df.ID[1] == 7 # assuming we only have the results for model 7 loaded

# ╔═╡ 7e86270e-0faf-4b05-b5b2-f446d62e3320
original_model = model_df.metagraph_model[1]

# ╔═╡ 003f7d18-1801-4eda-9092-1d8685e41da6
original_aeon =
    """
\$v_Coup_fti: !(v_Fgf8 | v_Sp8) | !(v_Sp8 | v_Fgf8)
\$v_Emx2: v_Coup_fti & !(v_Fgf8 | v_Sp8 | v_Pax6)
\$v_Fgf8: v_Fgf8 & v_Sp8 & !v_Emx2
\$v_Pax6: v_Sp8 & !(v_Emx2 | v_Coup_fti)
\$v_Sp8: v_Fgf8 & !v_Emx2
""" |> (
        x -> replace(
            x,
            "v_" => "",
            "\$" => "",
            "!" => "¬",
            "|" => "∨",
            "&" => "∧",
            "\n" => "\n",
        )
    )

# ╔═╡ cf9bb61c-7892-4b0b-91fe-e9c437be849d
Markdown.parse("""
```clingo
$original_aeon
```
""")

# ╔═╡ e699ff65-d7cc-4a9b-80b8-1fe4b17bb6ea
plot(
    reverse(original_model.graph);
    names = Dict([k => v.value[3:end] for (k, v) in original_model.vertex_labels]),
    nodecolor = :lightblue,
)

# ╔═╡ 38bcaaaf-5ddb-4536-b270-4b93caba66c2
(_, target_basins) = get_basins_bn(original_model)

# ╔═╡ 17aa2324-3b02-47c9-8c91-9bbdd4c3cb4a
steady_states = Iterators.flatten(values(target_basins)) |> collect

# ╔═╡ 749b6a19-a723-4df4-a37f-4d2d30f8d4e7
md"""
---

### Belongs-To Definitions

This might seem useless for now, because the entity is also in the solution name, but it is necessary with the way the model is currently defined. Otherwise, Clingo would not know the mapping.
"""

# ╔═╡ 50f0fcd3-e181-4d71-b833-8b67886806ab
md"""
### Connects Definitions

From our 4-tuple of results, we now need the `per-transition-success`, which looks like a vector of `BitVectors` (maybe should be a `BitArray`?).

> ```
> BitVector[[1, 0], [0, 1], [0, 1], [1, 0], [1, 0]]
> ```

The above `BitVectors` correspond to a solution that connects the first IO example from left (input) to right (output), the second from right to left, and so on.

So, to create the `connects(solution, state, state)` needs a map from the pairs to
"""

# ╔═╡ 7a58b03d-41d0-4380-85d2-231646807c5e
md"""
## Model Construction

Now that we have all of the ingredients, we can build the model and send it to Clingo to solve.

### Extra Checks

First, some checks to make sure the definitions above are correct-ish.

1. Are the entities lowercase, and only consisting of letters and numbers? Do they start with a letter?
"""

# ╔═╡ 458d40a7-b695-4307-aaae-b84ec75b1f56
md"""
2. Is there at least one state?
"""

# ╔═╡ 73360b3d-d702-4d82-9923-6aa7dccc08cf
md"""
3. Do all of the solution names start with one of the entity names from `vertex_names`? Are they followed by digits? Are they split with an underscore?
"""

# ╔═╡ 0dce9e1f-ad34-4a6a-b467-9517ee980f63
md"""
4. Does the pruning result in the same number of solutions as the "fingerprints" of solutions from their `per-transition-success` information?
"""

# ╔═╡ 32009cc3-b6de-4797-bc32-6bec42964d30
md"""
5. Does the pruning result in the same number of solutions `per-transition-success` information **per entity**?
"""

# ╔═╡ f5f4843c-eb6d-47e1-91c2-f92a817ce1e4
md"""
### Build Model File
"""

# ╔═╡ 1141d91e-ee98-4740-9765-ce1aa4f178cf
model_def = """

% For every entity, assign one solution. That solution must belong to the entity.
1 { assign(SOLUTION, ENTITY) : belongs_to(SOLUTION, ENTITY) } 1 :- entity(ENTITY).

% Edges connect states X and Y if a solution connects them and that solution is assigned
edge(X, Y) :- connects(SOLUTION, X, Y), assign(SOLUTION, _).
% A self-edge exists if X is steady and is a state
edge(X, X) :- steady(X), state(X).
% A path exists between X and Z if a an edge directly connects them
path(X, Z) :- edge(X, Z).
% A path from X to Z also exists if an edge connects X to an intermediate Y
% for which there exists a path connecting Y to Z
path(X, Z) :- edge(X, Y), path(Y, Z).

% :- state(X), steady(Y), not path(X, Y).
% There is a conflict if there is a non-steady state X and a steady state Y
% where there is not a path between X and Y
% conflict(X, Y)
:- state(X), not steady(X), steady(Y), not path(X, Y), path(Y, X).
% all states should have one outgoing edge
% conflict(X)
:- state(X), not path(X, _).
:- state(Y), steady(Y), state(X), not steady(X), path(Y, X).

% Output
% #show entity /1.
#show assign /2.
%#show edge /2.
%#show conflict /1.
"""

# ╔═╡ 5207cff2-6f14-4ced-a7c3-bcb5e899b83a
md"""
## Run Model
"""

# ╔═╡ 3010c862-fb99-4993-9109-d90b1ab04e46
md"""
Filter? $(@bind filtered PlutoUI.CheckBox(default=true))
"""

# ╔═╡ 02155e62-04d9-4c66-b29a-e4bb53e467d2
md"""
### Examine Solution

One solution from the unfiltered model is

> `assign(sp8_3210,sp8) assign(emx2_1128,emx2) assign(coupfti_3218,coupfti) assign(pax6_9228,pax6) assign(fgf8_5146,fgf8)`
"""

# ╔═╡ 26153e85-5a49-4376-a9ad-0e55ad6d1329
assignments = ["sp8_3210", "emx2_1128", "coupfti_3218", "pax6_9228", "fgf8_5146"]

# ╔═╡ 1de6aafa-9012-4027-a754-7e3ca811fb6a
md"""
All of the assignments should be in the solution names list.
"""

# ╔═╡ 1337307b-163c-4eb2-8d1f-702637837d01
md"""
What is their index in the original solutions? We need this to examine their transitions.
"""

# ╔═╡ b06e9728-6482-4082-baf5-d3ad63f02b16
first_transition = [
    BitVector([true, true]),
    BitVector([true, true]),
    BitVector([true, true]),
    BitVector([true, true]),
    BitVector([true, true]),
]

# ╔═╡ a5e7fab3-8e13-4e88-a452-72ac0617055a
md"""
### Examine Solution Edges
"""

# ╔═╡ ba1a2fcd-f825-4d06-aecf-486ea3584c5b
res_filtered = "edge(20,20) edge(10,10) assign(sp8_1409,sp8) assign(emx2_1393,emx2) assign(coupfti_1,coupfti) assign(pax6_6325,pax6) assign(fgf8_20,fgf8) edge(1,2) edge(4,3) edge(6,5) edge(8,7) edge(10,9) edge(11,12) edge(10,13) edge(3,14) edge(15,8) edge(6,11) edge(10,16) edge(2,14) edge(13,17) edge(4,18) edge(15,13) edge(12,1) edge(19,9) edge(20,2) edge(21,15) edge(16,18) conflict(1,20) conflict(2,20) conflict(3,20) conflict(4,20) conflict(5,20) conflict(6,20) conflict(7,20) conflict(8,20) conflict(9,20) conflict(11,20) conflict(12,20) conflict(13,20) conflict(14,20) conflict(15,20) conflict(16,20) conflict(17,20) conflict(18,20) conflict(19,20) conflict(21,20) conflict(1,10) conflict(2,10) conflict(3,10) conflict(4,10) conflict(5,10) conflict(6,10) conflict(7,10) conflict(8,10) conflict(9,10) conflict(11,10) conflict(12,10) conflict(13,10) conflict(14,10) conflict(15,10) conflict(16,10) conflict(17,10) conflict(18,10) conflict(19,10) conflict(21,10)"

# ╔═╡ 6feceb12-f887-4fed-a9a1-c085267188b5
res_sat = "edge(20,20) edge(10,10) assign(sp8_2282,sp8) assign(emx2_6156,emx2) assign(coupfti_3214,coupfti) assign(pax6_4797,pax6) assign(fgf8_1104,fgf8) edge(1,2) edge(7,8) edge(9,10) edge(3,4) edge(5,6) edge(11,12) edge(3,14) edge(13,10) edge(6,11) edge(4,18) edge(8,15) edge(14,2) edge(16,10) edge(17,13) edge(15,13) edge(12,1) edge(2,20) edge(19,9) edge(18,16) edge(21,15) edge(15,21) edge(16,18)"

# ╔═╡ 2457d4f1-a93f-407d-9e53-4e44f721568b
edges =
    res_sat |>
    split |>
    filter(startswith("edge")) .|>
    (x -> x[5:end]) .|>
    x ->
        replace(x, r"[()]" => "") .|>
        (x -> split(x, ",")) .|>
        (((x, y),) -> Pair(parse(Int, x), parse(Int, y)))

# ╔═╡ d50e737f-4bb2-40a7-a906-663a2d296cc1
graph = SimpleDiGraphFromIterator(Edge.(edges))

# ╔═╡ 113a60e4-8ef5-4d37-a978-d4ac9299d649
plot(
    graph;
    markersize = 0.25,
    fontsize = 6,
    names = 1:length(graph),
    curves = true,
    method = :spring,
    # nodesize=1,
    self_edge_size = 0.2,
)

# ╔═╡ 4d863e2c-e9a5-4c32-8776-5427744ff411
graph.fadjlist

# ╔═╡ 3eff6e0d-79d2-4974-afaf-cfffbc620bf4
md"""
### Setup
"""

# ╔═╡ 8d6fe0bd-b670-47a6-91c6-0f1db32584ad
PlutoUI.TableOfContents()

# ╔═╡ c3c26128-0e7e-4475-a057-591f74aec047
df = collect_results(datadir("exp_raw", "biodivine_search"));

# ╔═╡ c081cd85-b5af-4208-9ca8-90e2b1c02d0f
vertex_names_str = df.vertex_names |> unique |> only .|> x -> x[3:end]

# ╔═╡ 4f017c2b-7f3d-4ff8-95ba-6581c55ee5f3
vertex_names = replace.(lowercase.(vertex_names_str), "_" => "")

# ╔═╡ ed8ac9f3-e361-4e05-a160-bbb5e3c2b2a1
entity_string = "entity($(join(vertex_names, ";")))."

# ╔═╡ 0fe52af5-b1d2-4b7b-aab1-8bb34044a8e5
entity_string

# ╔═╡ 3bff2b94-eef4-4185-be8f-1bca5774ff13
@assert all(
    vertex_names |> Iterators.flatten |> collect |> filter(isletter) .|> islowercase,
)

# ╔═╡ 61442d48-1005-4caa-af78-138dfcecc064
@assert all(vertex_names |> Iterators.flatten |> collect |> filter(!isletter) .|> isdigit)

# ╔═╡ a1a95edc-2a28-48a1-84cf-6b1ed635ae34
@assert all(vertex_names .|> (x -> isletter(x[1])))

# ╔═╡ e1421a5b-11c7-44a8-b6f0-4654489a2b81
states = df.selected_trajectories |> Iterators.flatten |> Iterators.flatten |> unique

# ╔═╡ 8a2c00df-b9a9-42a2-ac0c-e243527545af
ids = eachindex(states)

# ╔═╡ 1c9ab992-a1d4-4a03-af70-358389149f15
state_string = "state(1..$(ids.stop))."

# ╔═╡ 5f6aa260-a6d7-4605-9a58-585b403f52e0
state_string

# ╔═╡ 79c72d39-c2af-4b5e-8370-49f8e652a733
@assert all(x -> x in states, steady_states)

# ╔═╡ fdd9a8d5-7bc0-4121-94d9-f6259e44e240
steady_ids = findfirst.(.==(steady_states), (states,))

# ╔═╡ 17cad63a-2003-4500-acef-a02c5567a428
steady_state_string = "steady($(join(steady_ids, ";")))."

# ╔═╡ dc058b46-0fa2-4197-a151-11ef46c892a7
steady_state_string

# ╔═╡ 4de0dced-294b-46c8-bb8a-c36922bf9df1
function raw_connection_builder(solution_name, successes, specifications)
    @assert length(successes) == length(specifications)
    raw_connections = Tuple{Int,Int}[]
    for (success, spec) in zip(successes, specifications)
        id1 = findfirst(==(spec[1]), states)
        id2 = findfirst(==(spec[2]), states)
        if success[1]
            push!(raw_connections, (id1, id2))
        end

        if success[2]
            push!(raw_connections, (id2, id1))
        end
    end

    return raw_connections
end

# ╔═╡ 15ac2c7c-c01c-4c3c-a145-84bbdfb788ca
function connection_builder(solution_name, successes, specifications)
    @assert length(successes) == length(specifications)
    connection_strings = String[]
    connects = (x, a, b) -> "connects($x, $a, $b)."
    for (success, spec) in zip(successes, specifications)
        id1 = findfirst(==(spec[1]), states)
        id2 = findfirst(==(spec[2]), states)
        if success[1]
            push!(connection_strings, connects(solution_name, id1, id2))
        end

        if success[2]
            push!(connection_strings, connects(solution_name, id2, id1))
        end
    end

    return connection_strings
end

# ╔═╡ 5840a8e6-1451-4637-9099-2256246baeb3
@assert length(states) > 0

# ╔═╡ 070c8187-736d-4fe6-adbd-923e38d4f731
states

# ╔═╡ 56fb75e5-f3ae-47af-a425-a92c784087a6
zip(vertex_names, eachcol((hcat(states...)')))

# ╔═╡ ac6532ec-3bd6-46e0-9ca9-8b3f18006fd3
permutedims(DataFrame(zip(vertex_names, eachcol((hcat(states...)')))), 1)

# ╔═╡ b917a2ab-f41a-45ff-83a4-60cb43c9feb3
sol_ids = [df.exprs_and_scores[i] .|> (x -> x[4]) for i in eachindex(df.exprs_and_scores)]

# ╔═╡ e495d254-df86-4ff4-9c3c-cfcbf8c8781e
length.(sol_ids)

# ╔═╡ 691e4ff4-177a-4a12-b353-6cfc2b4180be
solution_names_stacked = [
    ["$(vertex_names[vert])_$id" for id in sol_ids[vert]] for
    vert in eachindex(vertex_names)
]

# ╔═╡ 1996288a-5696-4d59-ab5f-f8f64dae1954
solution_names = solution_names_stacked |> Iterators.flatten |> collect

# ╔═╡ 356f324b-43bc-4f55-8c59-1582e35daf57
solution_strings = ["solution($x)." for x in solution_names]

# ╔═╡ 129079df-3878-4534-bd53-309dc3dea2bf
md"""
### Solution Pruning

While we have $(length(solution_strings)) solutions, many of these solutions induce the same topology within the state space. If we only take the first (simplest) solution for each induced topology, we create much fewer constants for Clingo to work with, speeding up the grounding and possibly also the solving process. The per-transition successes show the topology each solution induces in the state space, so we can filter on unique values there.
"""

# ╔═╡ 20ea6a2d-bf12-4233-b142-14fcd6771ef3
@assert all(split.(solution_names, '_') .|> first |> unique .|> (x -> x in vertex_names))

# ╔═╡ 2235412f-48b1-4e85-915d-d2d37b2feabc
@assert all(split.(solution_names, '_') .|> last |> unique |> Iterators.flatten .|> isdigit)

# ╔═╡ 8f09510b-c354-4061-bbb4-c5c69a7e17fb
@assert all(in.('_', solution_names))

# ╔═╡ 52d6f600-0c64-40f3-a171-dab105bcb9fc
@assert all(length.(split.(solution_names, '_')) .== 2)

# ╔═╡ b8ae91eb-be7e-4794-9fdf-4379a7c6b9df
solution_names_stacked

# ╔═╡ b45ae1e4-00f7-4648-9048-432f52d1ab3b
sol_exprs_printable =
    [df.exprs_and_scores[i] .|> (x -> x[1]) for i in eachindex(df.exprs_and_scores)][1][999] |>
    string |>
    x -> replace(x, "SoleLogics.Atom{SubString{String}}: v_" => "")

# ╔═╡ 1c555d75-fa37-493f-9a6b-14bba03924da
pertransition_successes =
    [df.exprs_and_scores[i] .|> (x -> x[3]) for i in eachindex(df.exprs_and_scores)]

# ╔═╡ f561ee12-0bb4-476e-9873-9b0504282321
n_successes = length.(pertransition_successes)

# ╔═╡ 963c1b25-d58a-4823-aa58-5c68e5c3bb8a
md"""
Unfiltered, we see that we have $(join(n_successes, ", ", " and ")) solutions for each of the 5 nodes in the model.
"""

# ╔═╡ e79fe49c-1307-46ce-ac8e-f8a785f40e6a
unique_successes = pertransition_successes .|> unique

# ╔═╡ c379dbbe-5cdc-494e-9228-81be16c3a2d1
n_unique_successes = length.(unique_successes)

# ╔═╡ 191f4126-95a6-4686-a898-0f28b2a67352
sum(n_unique_successes)

# ╔═╡ 7052b305-fc5f-4277-9ef2-b27f817350c4
md"""
However, after filtering out unique values, we end up with only $(join(n_unique_successes, ", ", " and ")) for each!
"""

# ╔═╡ afcd3d60-5be0-46dd-ba09-ae2fc7089059
unique_indices = [unique(i -> x[i], eachindex(x)) for x in pertransition_successes]

# ╔═╡ 459a1a38-f0d2-41b2-9e10-38ed10caa135
solution_names_filtered_and_stacked =
    filtered ?
    [solutions[idxs] for (solutions, idxs) in zip(solution_names_stacked, unique_indices)] :
    solution_names_stacked

# ╔═╡ 29c3b786-82bd-40e7-bb1d-0aa1f3e7921d
solution_names_filtered =
    solution_names_filtered_and_stacked |> Iterators.flatten |> collect

# ╔═╡ 80d449f8-13ea-40d4-b3bd-58ca766a15ae
solution_strings_filtered = ["solution($x)." for x in solution_names_filtered]

# ╔═╡ 36d8a531-a6c2-49eb-95ed-741c16b76209
solution_strings_filtered

# ╔═╡ 065f36d0-ea7e-4eb7-a82c-5236c3df0044
belongs_to_strings = [
    "belongs_to($(entity)_$id, $entity)." for
    (entity, id) in split.(solution_names_filtered, "_")
]

# ╔═╡ e6f5276e-5660-435a-a151-8af927b0c301
belongs_to_strings

# ╔═╡ feb6c350-5eb9-462d-8ba9-6185fe97441c
@assert all(in.(assignments, (solution_names_filtered,)))

# ╔═╡ c56a5fa7-18e9-4257-9bea-b85e51faeaca
sol_idxs = [
    only(findall(==(assignments[i]), solution_names_filtered_and_stacked[i])) for
    i in eachindex(assignments)
]

# ╔═╡ 52f6ab50-9c4f-41b4-b9f7-8a47cdad6c42
@assert filtered ?
        (solution_names_filtered |> length) ==
        (pertransition_successes |> Iterators.flatten |> unique |> length) : true

# ╔═╡ 982b0fab-1eee-4231-a656-557484fb0aaf
pertransition_successes |>
Iterators.flatten |>
Iterators.flatten |>
Iterators.flatten |>
count

# ╔═╡ 08f84a71-db13-47ff-8144-d6879fd7cb3c
pertransition_successes .|> unique |> Iterators.flatten |> collect

# ╔═╡ 28af4ee4-0fb6-4377-b17d-ed1e8d1d3598
pertransition_successes |> Iterators.flatten |> collect

# ╔═╡ 97c803c6-00c0-42e0-9c97-ff015a51335c
pertransition_successes |> Iterators.flatten .|> unique |> collect

# ╔═╡ 8b570775-6afe-435d-b3f6-4030b0df5e6c
sol_trans = [pertransition_successes[i][sol_idxs[i]] for i in eachindex(sol_idxs)]

# ╔═╡ 56e58ef6-e48f-4971-ba3b-e88a0957b4c7
first_transition in (pertransition_successes |> Iterators.flatten |> unique)

# ╔═╡ 49112c99-533c-4f96-acfe-1f660df01d74
df.selected_trajectories .|> first

# ╔═╡ 2ba7e499-44e0-435d-8f2f-dba92a7270fe
foreach(x -> println(x), df.selected_trajectories[1])

# ╔═╡ 9fe9fae0-ef94-4b40-89ea-32eb314013d0
sol_connections =
    [df.exprs_and_scores[i] .|> (x -> x[3]) for i in eachindex(df.exprs_and_scores)]

# ╔═╡ 414b38e6-c0c1-4429-907e-a7f836f5312c
trajectories =
    [df.selected_trajectories[i] .|> collect for i in eachindex(df.selected_trajectories)]

# ╔═╡ 072404b8-a243-4b40-86ea-52393754de4f
raw_connections_stacked = [
    [raw_connection_builder(name[i], conn[i], traj) for i in eachindex(name)] for
    (name, conn, traj) in
    zip(solution_names_filtered_and_stacked, sol_connections, trajectories)
]

# ╔═╡ 4a4190e7-6c01-47b6-801c-97b3f3165050
raw_connections_stacked |> Iterators.flatten |> Iterators.flatten |> collect |> length

# ╔═╡ 75257860-f733-441f-95ee-93c6d1b7ae2a
connection_strings_stacked = [
    [connection_builder(name[i], conn[i], traj) for i in eachindex(name)] for
    (name, conn, traj) in
    zip(solution_names_filtered_and_stacked, sol_connections, trajectories)
]

# ╔═╡ 56448558-2952-4764-8766-36e8c62d1de5
connection_strings =
    connection_strings_stacked |> Iterators.flatten |> Iterators.flatten |> collect

# ╔═╡ caf5fbec-f323-45ed-94c9-bfd0957ff97c
connection_strings

# ╔═╡ b563aa33-ee26-4c12-98f6-65d02cd3899d
mktemp() do path, io
    println(io, entity_string)
    println(io, state_string)
    for x in solution_strings_filtered
        println(io, x)
    end
    println(io, steady_state_string)
    for x in belongs_to_strings
        println(io, x)
    end
    for x in connection_strings
        println(io, x)
    end
    println(io, model_def)
    close(io)
    @show length(readlines(path))

    run(pipeline(ignorestatus(`$(Clingo_jll.clingo()) -n1 $path`)))
end

# ╔═╡ 25dd6bf1-4ca2-4084-b682-858020d90bbc
sol_exprs = [df.exprs_and_scores[i] .|> (x -> x[1]) for i in eachindex(df.exprs_and_scores)]

# ╔═╡ d5b485db-6b4d-4ede-ae64-bf8448451ddf
selected_exprs = [sol_exprs[i][sol_idxs[i]] for i in eachindex(sol_idxs)]

# ╔═╡ Cell order:
# ╟─f09edd39-ffeb-4850-b29e-b38565273ff5
# ╟─c081cd85-b5af-4208-9ca8-90e2b1c02d0f
# ╠═4f017c2b-7f3d-4ff8-95ba-6581c55ee5f3
# ╠═ed8ac9f3-e361-4e05-a160-bbb5e3c2b2a1
# ╟─701cca9d-f8de-4160-8f5d-c1ce30d31525
# ╟─e1421a5b-11c7-44a8-b6f0-4654489a2b81
# ╟─8a2c00df-b9a9-42a2-ac0c-e243527545af
# ╟─1c9ab992-a1d4-4a03-af70-358389149f15
# ╟─690734ed-bdbf-4635-a4d2-37500fcea3cf
# ╠═b917a2ab-f41a-45ff-83a4-60cb43c9feb3
# ╠═b45ae1e4-00f7-4648-9048-432f52d1ab3b
# ╠═e495d254-df86-4ff4-9c3c-cfcbf8c8781e
# ╠═691e4ff4-177a-4a12-b353-6cfc2b4180be
# ╠═1996288a-5696-4d59-ab5f-f8f64dae1954
# ╠═356f324b-43bc-4f55-8c59-1582e35daf57
# ╟─129079df-3878-4534-bd53-309dc3dea2bf
# ╠═b8ae91eb-be7e-4794-9fdf-4379a7c6b9df
# ╟─1c555d75-fa37-493f-9a6b-14bba03924da
# ╟─f561ee12-0bb4-476e-9873-9b0504282321
# ╟─963c1b25-d58a-4823-aa58-5c68e5c3bb8a
# ╠═e79fe49c-1307-46ce-ac8e-f8a785f40e6a
# ╟─c379dbbe-5cdc-494e-9228-81be16c3a2d1
# ╠═191f4126-95a6-4686-a898-0f28b2a67352
# ╟─7052b305-fc5f-4277-9ef2-b27f817350c4
# ╠═afcd3d60-5be0-46dd-ba09-ae2fc7089059
# ╠═459a1a38-f0d2-41b2-9e10-38ed10caa135
# ╠═29c3b786-82bd-40e7-bb1d-0aa1f3e7921d
# ╠═80d449f8-13ea-40d4-b3bd-58ca766a15ae
# ╟─51f9d1b9-304e-417f-9925-b572a90e278e
# ╟─f298831c-8954-4957-a2b9-92f7b0cf9ca7
# ╟─b8265bb9-83d4-4bfd-9480-a9b55d78495e
# ╠═437a480c-e63d-40f2-9d01-dd95275a333c
# ╠═7e86270e-0faf-4b05-b5b2-f446d62e3320
# ╠═003f7d18-1801-4eda-9092-1d8685e41da6
# ╠═cf9bb61c-7892-4b0b-91fe-e9c437be849d
# ╠═e699ff65-d7cc-4a9b-80b8-1fe4b17bb6ea
# ╠═49112c99-533c-4f96-acfe-1f660df01d74
# ╠═38bcaaaf-5ddb-4536-b270-4b93caba66c2
# ╠═17aa2324-3b02-47c9-8c91-9bbdd4c3cb4a
# ╠═79c72d39-c2af-4b5e-8370-49f8e652a733
# ╠═fdd9a8d5-7bc0-4121-94d9-f6259e44e240
# ╠═17cad63a-2003-4500-acef-a02c5567a428
# ╟─749b6a19-a723-4df4-a37f-4d2d30f8d4e7
# ╠═065f36d0-ea7e-4eb7-a82c-5236c3df0044
# ╠═2ba7e499-44e0-435d-8f2f-dba92a7270fe
# ╟─50f0fcd3-e181-4d71-b833-8b67886806ab
# ╠═9fe9fae0-ef94-4b40-89ea-32eb314013d0
# ╠═4de0dced-294b-46c8-bb8a-c36922bf9df1
# ╠═15ac2c7c-c01c-4c3c-a145-84bbdfb788ca
# ╠═414b38e6-c0c1-4429-907e-a7f836f5312c
# ╠═072404b8-a243-4b40-86ea-52393754de4f
# ╠═75257860-f733-441f-95ee-93c6d1b7ae2a
# ╠═56448558-2952-4764-8766-36e8c62d1de5
# ╟─7a58b03d-41d0-4380-85d2-231646807c5e
# ╠═3bff2b94-eef4-4185-be8f-1bca5774ff13
# ╠═61442d48-1005-4caa-af78-138dfcecc064
# ╠═a1a95edc-2a28-48a1-84cf-6b1ed635ae34
# ╟─458d40a7-b695-4307-aaae-b84ec75b1f56
# ╠═5840a8e6-1451-4637-9099-2256246baeb3
# ╟─73360b3d-d702-4d82-9923-6aa7dccc08cf
# ╠═20ea6a2d-bf12-4233-b142-14fcd6771ef3
# ╠═2235412f-48b1-4e85-915d-d2d37b2feabc
# ╠═8f09510b-c354-4061-bbb4-c5c69a7e17fb
# ╠═52d6f600-0c64-40f3-a171-dab105bcb9fc
# ╟─0dce9e1f-ad34-4a6a-b467-9517ee980f63
# ╠═52f6ab50-9c4f-41b4-b9f7-8a47cdad6c42
# ╠═4a4190e7-6c01-47b6-801c-97b3f3165050
# ╠═982b0fab-1eee-4231-a656-557484fb0aaf
# ╟─32009cc3-b6de-4797-bc32-6bec42964d30
# ╠═08f84a71-db13-47ff-8144-d6879fd7cb3c
# ╠═28af4ee4-0fb6-4377-b17d-ed1e8d1d3598
# ╠═97c803c6-00c0-42e0-9c97-ff015a51335c
# ╟─f5f4843c-eb6d-47e1-91c2-f92a817ce1e4
# ╠═0fe52af5-b1d2-4b7b-aab1-8bb34044a8e5
# ╠═5f6aa260-a6d7-4605-9a58-585b403f52e0
# ╠═36d8a531-a6c2-49eb-95ed-741c16b76209
# ╠═dc058b46-0fa2-4197-a151-11ef46c892a7
# ╠═e6f5276e-5660-435a-a151-8af927b0c301
# ╠═caf5fbec-f323-45ed-94c9-bfd0957ff97c
# ╠═1141d91e-ee98-4740-9765-ce1aa4f178cf
# ╟─5207cff2-6f14-4ced-a7c3-bcb5e899b83a
# ╟─3010c862-fb99-4993-9109-d90b1ab04e46
# ╠═b563aa33-ee26-4c12-98f6-65d02cd3899d
# ╟─02155e62-04d9-4c66-b29a-e4bb53e467d2
# ╠═26153e85-5a49-4376-a9ad-0e55ad6d1329
# ╟─1de6aafa-9012-4027-a754-7e3ca811fb6a
# ╠═feb6c350-5eb9-462d-8ba9-6185fe97441c
# ╟─1337307b-163c-4eb2-8d1f-702637837d01
# ╠═c56a5fa7-18e9-4257-9bea-b85e51faeaca
# ╠═8b570775-6afe-435d-b3f6-4030b0df5e6c
# ╠═b06e9728-6482-4082-baf5-d3ad63f02b16
# ╠═56e58ef6-e48f-4971-ba3b-e88a0957b4c7
# ╠═25dd6bf1-4ca2-4084-b682-858020d90bbc
# ╠═d5b485db-6b4d-4ede-ae64-bf8448451ddf
# ╟─a5e7fab3-8e13-4e88-a452-72ac0617055a
# ╟─ba1a2fcd-f825-4d06-aecf-486ea3584c5b
# ╠═6feceb12-f887-4fed-a9a1-c085267188b5
# ╠═2457d4f1-a93f-407d-9e53-4e44f721568b
# ╠═d50e737f-4bb2-40a7-a906-663a2d296cc1
# ╠═113a60e4-8ef5-4d37-a978-d4ac9299d649
# ╠═4d863e2c-e9a5-4c32-8776-5427744ff411
# ╠═070c8187-736d-4fe6-adbd-923e38d4f731
# ╠═56fb75e5-f3ae-47af-a425-a92c784087a6
# ╠═ac6532ec-3bd6-46e0-9ca9-8b3f18006fd3
# ╟─3eff6e0d-79d2-4974-afaf-cfffbc620bf4
# ╠═df97a629-608b-45d0-815d-0a6c1d37d95c
# ╠═8d6fe0bd-b670-47a6-91c6-0f1db32584ad
# ╠═b402713a-02a9-11f0-1bca-69b96cd9c786
# ╠═ca420cdc-208a-4341-8409-b2e826dcf9d7
# ╠═c3c26128-0e7e-4475-a057-591f74aec047
