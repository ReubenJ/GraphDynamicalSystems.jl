### A Pluto.jl notebook ###
# v0.19.47

using Markdown
using InteractiveUtils

# ╔═╡ 1a97f1a6-8a0d-11ef-3a8e-8da68a63985b
using DrWatson

# ╔═╡ 6d4d6baa-d160-47f3-bf7c-a9e0fabdf3c2
@quickactivate

# ╔═╡ 4aced393-1873-4fbf-b582-65a20346c64a
using Plots

# ╔═╡ 3ab50cf5-da53-440c-9796-c9ee73b7ad86
using SynthBN: AEONParser

# ╔═╡ 8a5e88c4-b0a6-4848-b6d2-74bdbd960e7c
using DataFrames

# ╔═╡ 8aaf540d-4e8b-499c-818f-3ce9f53a03cf
using JLD2

# ╔═╡ f1a1afae-a944-4cc8-8684-de76e8eb7922
md"""
# BN Synthesis with Biodivine Benchmarks
"""

# ╔═╡ 94df90c5-8431-4fca-a611-4a0ebcd14e80
md"""
## Benchmark Overview

The Biodivine Boolean model benchmark includes

"""

# ╔═╡ decf04d3-3ce0-4d3d-a046-1989994ad874
load(datadir("src_raw", "parsed_biodivine_benchmarks.jld2"))

# ╔═╡ 6f40fcb3-d8d1-4ade-a9ea-12fc58975f60
md"""
## Trajectories vs. Models Found

When varying the number of trajectories used for synthesis, we expect to see the number of models found to decrease, because more trajectories/information makes the specification more specific, limiting the size of the space of valid models.

We might expect to see some exponential decay like

```math
y = e^{-x/a} * b
```

with some rate `a` and scaling `b`.
"""

# ╔═╡ cc79a481-8bc9-442d-a129-a7f804ba0ccd
# ╠═╡ disabled = true
#=╠═╡
y₁ = [(x, ℯ^(-x/200) * 100_000) for x in 0:25:1000]
  ╠═╡ =#

# ╔═╡ 6989f31e-2256-4532-b885-e5354ed9e99a
#=╠═╡
scatter(
	y₁,
	xlabel="# of Trajectories",
	ylabel="# of models found",
	labels="",
	xlims=[0, 1000],
	ylims=[0, 100000]
)
  ╠═╡ =#

# ╔═╡ 9481ea51-b479-42a4-a5e8-03e0c4ea7387
md"""
### Packages Used

Keeping things tidy 🧹
"""

# ╔═╡ Cell order:
# ╟─f1a1afae-a944-4cc8-8684-de76e8eb7922
# ╟─94df90c5-8431-4fca-a611-4a0ebcd14e80
# ╠═decf04d3-3ce0-4d3d-a046-1989994ad874
# ╟─6f40fcb3-d8d1-4ade-a9ea-12fc58975f60
# ╠═cc79a481-8bc9-442d-a129-a7f804ba0ccd
# ╠═6989f31e-2256-4532-b885-e5354ed9e99a
# ╟─9481ea51-b479-42a4-a5e8-03e0c4ea7387
# ╠═1a97f1a6-8a0d-11ef-3a8e-8da68a63985b
# ╠═6d4d6baa-d160-47f3-bf7c-a9e0fabdf3c2
# ╠═4aced393-1873-4fbf-b582-65a20346c64a
# ╠═3ab50cf5-da53-440c-9796-c9ee73b7ad86
# ╠═8a5e88c4-b0a6-4848-b6d2-74bdbd960e7c
# ╠═8aaf540d-4e8b-499c-818f-3ce9f53a03cf
