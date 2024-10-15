### A Pluto.jl notebook ###
# v0.19.47

using Markdown
using InteractiveUtils

# ╔═╡ 70b96736-797d-11ef-2813-314ac85c3364
using DrWatson

# ╔═╡ cbd7f05b-bd2d-4fd1-a178-efe01459e45f
@quickactivate

# ╔═╡ ab9b3cf7-8faf-4c24-936c-428132697f91
using DataFrames, Herb, SoleLogics

# ╔═╡ 99e6781b-125c-4e27-9148-c44e8bb3519e
using MetaGraphsNext,
    DynamicalSystems, GraphDynamicalSystems, StatsPlots, GraphRecipes, Plots

# ╔═╡ ed88fb56-f1e7-4c9b-bb8f-639e40e74375
networks = collect_results(datadir("sims", "specs"));

# ╔═╡ 8466f8d0-3cd3-4dbe-ab1d-ff591a0bc3dd
networks_by_seed = groupby(networks, :seed);

# ╔═╡ 8bd06f89-5c7c-4a9d-8c9e-6f81f1a8cfa0
names(networks_by_seed)

# ╔═╡ 4fbf88ff-86ec-4447-859a-7e3c370b5e71
bn = networks[networks.seed.==1, :].bn[1]

# ╔═╡ b618790b-db83-4153-9737-e1a76773608e
bn.vertex_properties

# ╔═╡ cb9af591-329d-43dd-aa74-688fc888766c
graphplot(
    bn.graph,
    method = :circular,
    # names=[String(val[2]) for val in values(bn.vertex_properties)]
)

# ╔═╡ 70d17571-96a2-4cc4-9059-3c203e32b3c2
results = collect_results(datadir("exp_raw", "cnf_search"));

# ╔═╡ 1cb1376c-967c-4f71-9134-2654e255e179
by_grammar = groupby(results, [:grammar_type, :seed, :node]);

# ╔═╡ c478bf1a-451d-4469-8bd2-88a3a375907f
function get_found_after(results_node, expected_func)
    for (i, r) in enumerate(eachrow(results_node))
        (f, s) = r[1]
        if normalize(f) == normalize(expected_func)
            return i
        end
    end

    return Inf
end

# ╔═╡ 49c919a1-1bdf-497c-bdaa-de502711c0ef
dnf_node_1_ex_sc = by_grammar[("cnf", 0, 2)][!, :exprs_and_scores][1]

# ╔═╡ e22e7263-95c9-43cb-98b2-09dd3dba4b5b
bn_0_node_1 = networks_by_seed[(0,)].bn[1][2]

# ╔═╡ 36d246c7-edf1-4cf9-b4fd-50646f8387a1
get_found_after(dnf_node_1_ex_sc, bn_0_node_1)

# ╔═╡ 5e95a352-d09b-4996-87af-1977ea02717e
# @df dnf bar(
#     :node,
#     :found_after,
#     xlims = [0, 12],
#     xlabel = "Node In Network",
#     ylabel = "First Solution at # Iterations",
# )

# ╔═╡ 352515cd-c7fc-43bb-8761-33d93521e8ad
cnf_seed_1 = by_grammar[("cnf", 1, 1)];

# ╔═╡ 4499a2c8-d6a5-4417-b4ac-ea5e30289167
@df cnf_seed_1 bar(
    :node,
    :node,
    xlims = [0, 12],
    xlabel = "Node In Network",
    ylabel = "First Solution at # Iterations",
)

# ╔═╡ fe160a77-7064-4850-be33-7053911d8706
dnf.all_ex

# ╔═╡ 3e06906d-913c-4de0-8091-05f60347d4fe
cnf_seed_1.all_ex

# ╔═╡ Cell order:
# ╠═70b96736-797d-11ef-2813-314ac85c3364
# ╠═cbd7f05b-bd2d-4fd1-a178-efe01459e45f
# ╠═ab9b3cf7-8faf-4c24-936c-428132697f91
# ╠═99e6781b-125c-4e27-9148-c44e8bb3519e
# ╠═ed88fb56-f1e7-4c9b-bb8f-639e40e74375
# ╠═8466f8d0-3cd3-4dbe-ab1d-ff591a0bc3dd
# ╠═8bd06f89-5c7c-4a9d-8c9e-6f81f1a8cfa0
# ╠═4fbf88ff-86ec-4447-859a-7e3c370b5e71
# ╠═b618790b-db83-4153-9737-e1a76773608e
# ╠═cb9af591-329d-43dd-aa74-688fc888766c
# ╠═70d17571-96a2-4cc4-9059-3c203e32b3c2
# ╠═1cb1376c-967c-4f71-9134-2654e255e179
# ╠═c478bf1a-451d-4469-8bd2-88a3a375907f
# ╠═49c919a1-1bdf-497c-bdaa-de502711c0ef
# ╠═e22e7263-95c9-43cb-98b2-09dd3dba4b5b
# ╠═36d246c7-edf1-4cf9-b4fd-50646f8387a1
# ╠═5e95a352-d09b-4996-87af-1977ea02717e
# ╠═4499a2c8-d6a5-4417-b4ac-ea5e30289167
# ╠═352515cd-c7fc-43bb-8761-33d93521e8ad
# ╠═fe160a77-7064-4850-be33-7053911d8706
# ╠═3e06906d-913c-4de0-8091-05f60347d4fe
