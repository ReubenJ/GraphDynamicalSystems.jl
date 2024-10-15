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

# ╔═╡ f1a1afae-a944-4cc8-8684-de76e8eb7922
md"""
# Synthesis with Biodivine Benchmarks

The Biodivine Boolean model benchmark includes a
"""

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
y₁ = [(x, ℯ^(-x / 200) * 100_000) for x = 0:25:1000]

# ╔═╡ 6989f31e-2256-4532-b885-e5354ed9e99a
scatter(
    y₁,
    xlabel = "# of Trajectories",
    ylabel = "# of models found",
    labels = "",
    xlims = [0, 1000],
    ylims = [0, 100000],
)

# ╔═╡ Cell order:
# ╠═f1a1afae-a944-4cc8-8684-de76e8eb7922
# ╠═1a97f1a6-8a0d-11ef-3a8e-8da68a63985b
# ╠═6d4d6baa-d160-47f3-bf7c-a9e0fabdf3c2
# ╠═4aced393-1873-4fbf-b582-65a20346c64a
# ╟─6f40fcb3-d8d1-4ade-a9ea-12fc58975f60
# ╠═cc79a481-8bc9-442d-a129-a7f804ba0ccd
# ╠═6989f31e-2256-4532-b885-e5354ed9e99a
