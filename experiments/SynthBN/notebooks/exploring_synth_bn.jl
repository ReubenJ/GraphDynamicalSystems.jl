### A Pluto.jl notebook ###
# v0.19.46

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
networks = collect_results(datadir("sims", "specs"))

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
by_grammar = groupby(results, [:grammar_type, :seed]);

# ╔═╡ b5528ba0-b48e-41c6-bdf2-55260a71e33e
dnf = by_grammar[("dnf", 1)];

# ╔═╡ 5e95a352-d09b-4996-87af-1977ea02717e
@df dnf bar(
    :node,
    :found_after,
    xlims = [0, 12],
    xlabel = "Node In Network",
    ylabel = "First Solution at # Iterations",
)

# ╔═╡ 352515cd-c7fc-43bb-8761-33d93521e8ad
cnf = by_grammar[("cnf", 1)];

# ╔═╡ 4499a2c8-d6a5-4417-b4ac-ea5e30289167
@df cnf bar(
    :node,
    :found_after,
    xlims = [0, 12],
    xlabel = "Node In Network",
    ylabel = "First Solution at # Iterations",
)

# ╔═╡ fe160a77-7064-4850-be33-7053911d8706
dnf.all_ex

# ╔═╡ 3e06906d-913c-4de0-8091-05f60347d4fe
cnf.all_ex

# ╔═╡ Cell order:
# ╠═70b96736-797d-11ef-2813-314ac85c3364
# ╠═cbd7f05b-bd2d-4fd1-a178-efe01459e45f
# ╠═ab9b3cf7-8faf-4c24-936c-428132697f91
# ╠═99e6781b-125c-4e27-9148-c44e8bb3519e
# ╠═ed88fb56-f1e7-4c9b-bb8f-639e40e74375
# ╠═4fbf88ff-86ec-4447-859a-7e3c370b5e71
# ╠═b618790b-db83-4153-9737-e1a76773608e
# ╠═cb9af591-329d-43dd-aa74-688fc888766c
# ╠═70d17571-96a2-4cc4-9059-3c203e32b3c2
# ╠═1cb1376c-967c-4f71-9134-2654e255e179
# ╠═5e95a352-d09b-4996-87af-1977ea02717e
# ╠═b5528ba0-b48e-41c6-bdf2-55260a71e33e
# ╠═4499a2c8-d6a5-4417-b4ac-ea5e30289167
# ╠═352515cd-c7fc-43bb-8761-33d93521e8ad
# ╠═fe160a77-7064-4850-be33-7053911d8706
# ╠═3e06906d-913c-4de0-8091-05f60347d4fe
