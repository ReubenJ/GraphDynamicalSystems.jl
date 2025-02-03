### A Pluto.jl notebook ###
# v0.19.46

using Markdown
using InteractiveUtils

# ╔═╡ 1a97f1a6-8a0d-11ef-3a8e-8da68a63985b
using DrWatson

# ╔═╡ 6d4d6baa-d160-47f3-bf7c-a9e0fabdf3c2
@quickactivate

# ╔═╡ 0a6d4236-f1ac-474d-be98-3c2a53dd9a46
using Graphs

# ╔═╡ 95417510-36db-451e-ba87-9faa23f7d412
using SoleLogics: Atom, subformulas, Formula

# ╔═╡ 4a7c619f-6ad6-43d6-b8e8-bddf4255bf17
using MetaGraphsNext: MetaGraph

# ╔═╡ 4aced393-1873-4fbf-b582-65a20346c64a
using Plots

# ╔═╡ 3ab50cf5-da53-440c-9796-c9ee73b7ad86
using Synth: AEONParser

# ╔═╡ 8a5e88c4-b0a6-4848-b6d2-74bdbd960e7c
using DataFrames

# ╔═╡ 8aaf540d-4e8b-499c-818f-3ce9f53a03cf
using JLD2

# ╔═╡ 6ef6f82a-5869-42c6-9111-ae125414ab1c
using StatsPlots

# ╔═╡ 0f49994b-f5fe-4083-b06e-2a4b99ed9200
using TidierData

# ╔═╡ 1dd2589a-baad-415a-a842-9f3701812f8e
using PlutoUI

# ╔═╡ d202a3b0-913d-4a63-a81c-cfb64f2e5176
using PlutoTeachingTools

# ╔═╡ 7cb5d22d-4a2e-483e-a567-77c09fda306b
using AbstractTrees

# ╔═╡ 016ede63-6f1c-4d38-81bf-77b4538c4705
md"""
## Variables
"""

# ╔═╡ 1121b33a-d9e9-4cb8-b15e-2a75d98453d7
md"""
## Inputs
"""

# ╔═╡ 253c2d2c-5d77-4de6-bb00-27eb4b0ebc07
md"""
## Regulations/Edges
"""

# ╔═╡ dc0fcf4b-ccb4-4e28-8ffb-268145008f23
md"""
Average number of reglations/edges per node. Note that this is not necessarily proportional to the size of the target function.
"""

# ╔═╡ 6f40fcb3-d8d1-4ade-a9ea-12fc58975f60
md"""
# Experiments
## \# Trajectories vs. Models Found

When varying the number of trajectories used for synthesis, we expect to see the number of models found to decrease, because more trajectories/information makes the specification more specific, limiting the size of the space of valid models.

We might expect to see some exponential decay like

```math
y = e^{-x/a} * b
```

with some rate `a` and scaling `b`.
"""

# ╔═╡ cc79a481-8bc9-442d-a129-a7f804ba0ccd
y₁ = [(x, ℯ^(-x / 200) * 100_000) for x = 0:25:1000];

# ╔═╡ 6989f31e-2256-4532-b885-e5354ed9e99a
scatter(
    y₁,
    xlabel = "# of Trajectories",
    ylabel = "# of models found per node",
    labels = "",
    xlims = [0, 1000],
    ylims = [0, 100000],
)

# ╔═╡ 39e255ea-1251-4b3b-a5bc-0cd65491020b
md"""
Notes
- Fix number of iterations, size of target functions
- Plot per node
- Size of the network as weighting for the points on the scatterplot
- Filter such that none of the trajectories have the same initial condition
"""

# ╔═╡ 1f8e149a-0c73-48b1-b9f1-74887c5fdeac
md"""
## \# Iterations until First Model

- Per node
- Weighting based on network size
"""

# ╔═╡ 99efeb26-41a8-4600-9aa8-8c9b88987ad7
histogram()

# ╔═╡ 196936b8-2dbf-4c56-8544-4a66a8b911af
md"""
## Average Deg. of Networks
"""

# ╔═╡ 847d131e-f310-4d43-80b4-c120c9832eee
md"""
## Network Size vs. \# Models Found

For a fixed number of trajectories.
"""

# ╔═╡ 0bac6f39-6683-4a08-bdad-31d232be36e7
plot()

# ╔═╡ b6b12ecb-995d-4fd2-82cf-0485c4ff1cf1
md"""
Notes
- Average per node
- Limit function sizes
  - Implicitely limits iterations
"""

# ╔═╡ 84fda41b-1309-4a58-be79-b517baf0814f
md"""
## Global Clustering Coef. vs. \# Models Found

- [Global clustering coefficient on Wikipedia](https://en.wikipedia.org/wiki/Clustering_coefficient#Global_clustering_coefficient)
"""

# ╔═╡ e5636bd9-5e8e-46dd-9b6c-a66497d7df95
plot()

# ╔═╡ c4a84267-fc57-4a5d-b2ae-5db24896108d
md"""
# Appendix

📊 Data loading, packages, etc. etc.

## Data, Theme

Loading files, setting up colors, etc.
"""

# ╔═╡ 74c47afc-98ab-44a3-bc8b-2a104fbffb07
plot_color_theme = cgrad(:matter, 5, categorical = true)

# ╔═╡ a2e21a23-3fc0-492a-9b27-cb7f307fcb1d
excluded_files = [r"041\.aeon\.jld2", r"079\.aeon\.jld2"]

# ╔═╡ decf04d3-3ce0-4d3d-a046-1989994ad874
begin
    df = collect_results!(
        datadir("src_parsed", "biodivine_benchmark");
        rexclude = excluded_files,
    )
    # "full/path/to/001.aeon.jld2" -> "001"
    df.ID = map((x -> x[1]) ∘ splitext ∘ (x -> x[1]) ∘ splitext ∘ basename, df.path)
end

# ╔═╡ f1a1afae-a944-4cc8-8684-de76e8eb7922
md"""
# BN Synthesis with Biodivine Benchmarks

🧑‍💻 [github.com/sybila/biodivine-boolean-models](https://github.com/sybila/biodivine-boolean-models)

$((!isdefined(@__MODULE__, :df) || nrow(df) == 0) ? danger(md"It seems that the dataframe with the benchmark information failed to load, or it was empty. Try running the script:

`julia experiments/Synth/scripts/biodivine_benchmark/load_aeon.jl`

to load/parse the benchmark.") : md"")
"""

# ╔═╡ 94df90c5-8431-4fca-a611-4a0ebcd14e80
md"""
## Benchmark Overview

The Biodivine Boolean model benchmark includes
$(length(excluded_files) > 0 ? nrow(df) + length(excluded_files) : nrow(df))
models.
$(length(excluded_files) > 0 ? "We currently drop two (#079, and #041) because 79 causes JLD2 to crash upon deserializing, and 41 causes some weird `#undef` error." : "")

The models have a varying number of `variables`, `inputs` (nodes with no incoming `regulations`/`edges`), and `regulations` (`edges`).
"""

# ╔═╡ ca807ea7-1980-4800-91f8-7b446923127a
components_df = let UpdateFunction = AEONParser.UpdateFunction
    @chain df begin
        @select parsed_model ID
        flatten(:parsed_model)
        # Twice because I've accidentally added each component as a vector of length 1
        flatten(:parsed_model)
        @rename Component = parsed_model  # new = old
        @mutate ComponentType = typeof(Component)
        @group_by ComponentType
    end
end;

# ╔═╡ ed381482-fc40-4378-90b0-df86a474c864
just_update_functions = components_df[(ComponentType = AEONParser.UpdateFunction,)];

# ╔═╡ a0f79b65-31d0-4faa-b87a-28335501ed61
update_functions = @chain just_update_functions begin
    @group_by ID
    @select Component
end;

# ╔═╡ 022aad38-22e5-4d4d-a29a-3c4b900ab974
function update_functions_to_network(
    update_functions::AbstractVector{<:AEONParser.UpdateFunction},
)
    network = MetaGraph(SimpleDiGraph(); label_type = String, vertex_data_type = Formula)

    for up in update_functions
        network[up.target.name] = up.fn
    end

    for up in update_functions
        atoms = filter(x -> isa(x, Atom), subformulas(up.fn))
        for atom in atoms
            source = atom.value
            add_edge!(network, up.target.name, source)
        end
    end

    return network
end

# ╔═╡ baff69b5-5af7-4aaf-a1eb-846216deffc5
metagraph_models = combine(
    update_functions[1:20],
    :Component =>
        x ->
            update_functions_to_network(Vector{AEONParser.UpdateFunction}(x)) =>
                :Network,
);

# ╔═╡ e7ad15ac-8976-4100-83ce-e964a6489605
Dict(names(metagraph_models[1, :]) .=> values(metagraph_models[1, :]))

# ╔═╡ 4d26800f-12b6-4ffe-b6e1-8db8834a8da9
with_fn_arity_df = let UpdateFunction = AEONParser.UpdateFunction
    with_fn_arity_df = deepcopy(just_update_functions)
    with_fn_arity_df[!, :Arity] .=
        length.(collect.(Leaves.(map(x -> x.fn, just_update_functions[!, :Component]))))
    with_fn_arity_df
end;

# ╔═╡ c30f1640-42f4-4538-a5e0-ede64784bed1
with_mean_arity_df = @chain with_fn_arity_df begin
    @group_by ID
    @summarize mean_arity = mean(Arity)
end;

# ╔═╡ 7f4d4333-d66e-4ddb-8448-21db9bdc6c6d
histogram(
    with_mean_arity_df.mean_arity,
    ylim = (0, 120),
    color = cgrad(:matter, 5, categorical = true)[1],
    legend = nothing,
    xlabel = "Mean Update Function Arity",
    ylabel = "# Models",
)

# ╔═╡ e4f087f0-4c83-408d-a9a1-5bb1447a1da7
raw_summary_df = load(datadir("src_parsed", "summary_biodivine_benchmark.jld2"))["df"];

# ╔═╡ fab25481-21f9-490f-974f-6ea88177f68f
summary_names = map(strip, names(raw_summary_df))

# ╔═╡ 9f2c259a-479d-483a-9cf5-c249b6049dd6
summary_df = rename(raw_summary_df, summary_names);

# ╔═╡ 30597336-77c9-4d68-a9b4-065469b1b228
histogram(
    summary_df.variables,
    ylims = (0, 100),
    xlabel = "Variables",
    ylabel = "# Models",
    legend = nothing,
    color = plot_color_theme[1],
)

# ╔═╡ 2bcbfef7-c44b-413e-929e-d6535ef0edf3
histogram(
    summary_df.inputs,
    ylim = (0, 120),
    xlabel = "Inputs",
    ylabel = "# Models",
    legend = nothing,
    color = cgrad(:matter, 5, categorical = true)[2],
)

# ╔═╡ 1da7e7ee-99a2-4e3e-9ffc-ee2b246f5da4
histogram(
    summary_df.regulations,
    ylim = (0, 80),
    color = cgrad(:matter, 5, categorical = true)[3],
    legend = nothing,
    xlabel = "Regulations",
    ylabel = "# Models",
)

# ╔═╡ ff760751-c7e6-4085-b96e-45e2732f6b5f
avg_deg = histogram(
    summary_df.regulations ./ summary_df.variables,
    ylim = (0, 80),
    color = cgrad(:matter, 5, categorical = true)[4],
    legend = nothing,
    xlabel = "Regulations / Node",
    ylabel = "# Models",
)


# ╔═╡ 658bb88d-274f-4807-b18d-966eb9424e28
avg_deg

# ╔═╡ 28a1addd-059c-419c-ba7b-1564b875f0e6
summary_stats = describe(summary_df);

# ╔═╡ 813cd252-659f-4ee5-89ad-d78a183928f3
TableOfContents()

# ╔═╡ 76ec0b17-05ad-40bd-b922-6ad14e619013
space = html"<br><br><br>"

# ╔═╡ 21d9f3cd-d68d-4f9d-9b3c-d31d7383c872
space

# ╔═╡ 55e55e42-9186-4e04-a7f4-f433499b62b0
space

# ╔═╡ 9481ea51-b479-42a4-a5e8-03e0c4ea7387
md"""
## Packages Used

Keeping things tidy 🧹
"""

# ╔═╡ 31dff5a3-6912-42d1-a8dd-932bb618e21f
plotly()

# ╔═╡ Cell order:
# ╟─f1a1afae-a944-4cc8-8684-de76e8eb7922
# ╟─94df90c5-8431-4fca-a611-4a0ebcd14e80
# ╟─016ede63-6f1c-4d38-81bf-77b4538c4705
# ╟─30597336-77c9-4d68-a9b4-065469b1b228
# ╟─1121b33a-d9e9-4cb8-b15e-2a75d98453d7
# ╟─2bcbfef7-c44b-413e-929e-d6535ef0edf3
# ╟─253c2d2c-5d77-4de6-bb00-27eb4b0ebc07
# ╟─1da7e7ee-99a2-4e3e-9ffc-ee2b246f5da4
# ╟─dc0fcf4b-ccb4-4e28-8ffb-268145008f23
# ╟─ff760751-c7e6-4085-b96e-45e2732f6b5f
# ╟─7f4d4333-d66e-4ddb-8448-21db9bdc6c6d
# ╟─21d9f3cd-d68d-4f9d-9b3c-d31d7383c872
# ╟─6f40fcb3-d8d1-4ade-a9ea-12fc58975f60
# ╠═cc79a481-8bc9-442d-a129-a7f804ba0ccd
# ╟─6989f31e-2256-4532-b885-e5354ed9e99a
# ╟─39e255ea-1251-4b3b-a5bc-0cd65491020b
# ╟─1f8e149a-0c73-48b1-b9f1-74887c5fdeac
# ╠═99efeb26-41a8-4600-9aa8-8c9b88987ad7
# ╟─196936b8-2dbf-4c56-8544-4a66a8b911af
# ╟─658bb88d-274f-4807-b18d-966eb9424e28
# ╟─847d131e-f310-4d43-80b4-c120c9832eee
# ╠═0bac6f39-6683-4a08-bdad-31d232be36e7
# ╟─b6b12ecb-995d-4fd2-82cf-0485c4ff1cf1
# ╟─84fda41b-1309-4a58-be79-b517baf0814f
# ╠═e5636bd9-5e8e-46dd-9b6c-a66497d7df95
# ╟─55e55e42-9186-4e04-a7f4-f433499b62b0
# ╟─c4a84267-fc57-4a5d-b2ae-5db24896108d
# ╠═74c47afc-98ab-44a3-bc8b-2a104fbffb07
# ╠═a2e21a23-3fc0-492a-9b27-cb7f307fcb1d
# ╠═decf04d3-3ce0-4d3d-a046-1989994ad874
# ╠═ca807ea7-1980-4800-91f8-7b446923127a
# ╠═ed381482-fc40-4378-90b0-df86a474c864
# ╠═a0f79b65-31d0-4faa-b87a-28335501ed61
# ╠═baff69b5-5af7-4aaf-a1eb-846216deffc5
# ╠═e7ad15ac-8976-4100-83ce-e964a6489605
# ╠═0a6d4236-f1ac-474d-be98-3c2a53dd9a46
# ╠═95417510-36db-451e-ba87-9faa23f7d412
# ╠═4a7c619f-6ad6-43d6-b8e8-bddf4255bf17
# ╠═022aad38-22e5-4d4d-a29a-3c4b900ab974
# ╠═4d26800f-12b6-4ffe-b6e1-8db8834a8da9
# ╠═c30f1640-42f4-4538-a5e0-ede64784bed1
# ╠═e4f087f0-4c83-408d-a9a1-5bb1447a1da7
# ╠═fab25481-21f9-490f-974f-6ea88177f68f
# ╠═9f2c259a-479d-483a-9cf5-c249b6049dd6
# ╠═28a1addd-059c-419c-ba7b-1564b875f0e6
# ╠═813cd252-659f-4ee5-89ad-d78a183928f3
# ╟─76ec0b17-05ad-40bd-b922-6ad14e619013
# ╟─9481ea51-b479-42a4-a5e8-03e0c4ea7387
# ╠═1a97f1a6-8a0d-11ef-3a8e-8da68a63985b
# ╠═6d4d6baa-d160-47f3-bf7c-a9e0fabdf3c2
# ╠═4aced393-1873-4fbf-b582-65a20346c64a
# ╠═31dff5a3-6912-42d1-a8dd-932bb618e21f
# ╠═3ab50cf5-da53-440c-9796-c9ee73b7ad86
# ╠═8a5e88c4-b0a6-4848-b6d2-74bdbd960e7c
# ╠═8aaf540d-4e8b-499c-818f-3ce9f53a03cf
# ╠═6ef6f82a-5869-42c6-9111-ae125414ab1c
# ╠═0f49994b-f5fe-4083-b06e-2a4b99ed9200
# ╠═1dd2589a-baad-415a-a842-9f3701812f8e
# ╠═d202a3b0-913d-4a63-a81c-cfb64f2e5176
# ╠═7cb5d22d-4a2e-483e-a567-77c09fda306b
