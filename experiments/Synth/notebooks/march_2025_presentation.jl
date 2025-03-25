### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ b6578081-a6fe-4637-903e-4435f7e6c749
using DrWatson

# ╔═╡ d03d06ee-5614-4fdd-889d-48c8710b261c
begin
    quickactivate(@__DIR__)
    using Revise
    using GraphDynamicalSystems
    using Synth
    using Herb
    using MetaGraphsNext: labels
    using SoleLogics: value, Atom
    # using ProgressMeter, DataFrames, HerbSearch, Random
    # using MetaGraphsNext: labels
    # using Statistics: quantile
    # using DynamicalSystems
    # using Clingo_jll
    # using Plots
    # using Graphs
    # using GraphRecipes
    using PlutoUI
    # using Herb
    # using SoleLogics
    using MLStyle
    import HerbConstraints.pattern_match
    using HerbConstraints:
        PatternMatchResult,
        PatternMatchSuccess,
        PatternMatchSoftFail,
        PatternMatchHardFail,
        PatternMatchSuccessWhenHoleAssignedTo
end

# ╔═╡ fa93f89e-05ab-11f0-2dfe-f1e019d9bfe8
html"""
<h1></h1>
<div id="titlebox">
<p class="noborder">
<span class="gone">Synthesizing</span>
<span class="verylight"><i>Networks of State Machines</i></span>
</p>
<p class="noborder">
<span class="gone">Synthesizing</span>
<span class="light"><i>Dynamical Systems</i></span>
</p>

<p style="border-bottom: none">Synthesizing <i>Biological Models</i></p>
<p class="noborder">
<span class="gone">Synthesizing</span>
<span class="light"><i>Qualitative Networks</i></span>
</p>
<p class="noborder">
<span class="gone">Synthesizing</span>
<span class="verylight"><i>Boolean Networks</i></span>
</p>
</div>

<div style="text-align: center">03/26/2024 Update Meeting</div>

"""

# ╔═╡ a1718e12-bfdf-44fe-a930-c9131e64d144
md"""
## Agenda

1. Unified formulation of the synthesis problem
2. What we have
3. What we're missing
4. Questions
"""

# ╔═╡ 3e8e48cc-790c-4a18-990a-637372d432d2
md"""
## Synthesis Problem Formulation
"""

# ╔═╡ ef9ea3aa-1022-409e-8b6e-d79e0455bfc8
md"""
## ✓ What we have
"""

# ╔═╡ f00faa20-d261-433d-908e-8047b5a5d45a
md"""
### Walk through
"""

# ╔═╡ d4604287-fde2-4fc9-961b-4505e8210551
md"""
## ❗ What we're missing
"""

# ╔═╡ 426f51b8-c9ec-42e9-8d21-9573183f48f4
md"""
## ❓ Questions
"""

# ╔═╡ cdc9908c-d858-4cee-ac08-2b135e8aabd2
md"""
# Appendix
"""

# ╔═╡ f9e3c41e-1ab9-4a58-aaad-5c97c888728c
md"""
## Data Loading
"""

# ╔═╡ 48bf71ae-ca36-40aa-a65f-e7eb37953058
begin
    model_df = collect_results(datadir("src_parsed", "biodivine_benchmark_as_metagraphs");)
    path2id = path -> parse(Int, splitext(basename(path))[1])
    model_df.ID = path2id.(model_df.path)
    model007 = only(model_df[model_df.ID.==7, :metagraph_model])
end

# ╔═╡ 94d4c053-c02e-4a07-93b2-63438759acb8
begin
    trajectories = []
    for i = 1:10
        abn7 = BooleanNetworks.abn(model007; seed = i)
        data = gather_bn_data(abn7, 10)
        push!(trajectories, data)
    end
    states = trajectories |> Iterators.flatten |> unique
end

# ╔═╡ 754c499a-28e3-42fb-bed3-e466ed1c7393
begin
    io_pairs = []
    for (i, s) in enumerate(states)
        adjacents = states .- (s,) .|> (x -> abs.(x)) .|> sum .|> ==(1)

        for other_state in states[adjacents]
            push!(io_pairs, (s, other_state))
        end
    end
    io_pairs
end

# ╔═╡ cd238a3a-d6a3-464b-a249-d2e66236ee50
unique_transitions = io_pairs .|> Set |> unique .|> collect

# ╔═╡ 911de256-b75e-4503-9702-c70e70be5779
entity_names = model007 |> labels .|> value .|> (x -> replace(x, "v_" => "")) .|> Symbol

# ╔═╡ 2cf1d0f3-5f6f-4fd7-ac97-9072f25f9917
problems = [
    UndirectedProblem(
        string(entity_names[i]),
        [
            UndirectedExample(Dict(:state => t[1]), Dict(:state => t[2])) for
            t in unique_transitions if t[1][i] != t[2][i]
        ],
    ) for i = 1:length(entity_names)
]

# ╔═╡ e6fdb952-424a-492f-b9a4-01984a4824bb
function build_qn_grammar(entity_names, constants = default_qn_constants)
    g = deepcopy(GraphDynamicalSystems.base_qn_grammar)
    n_original_rules = length(g.rules)
    n_entities = length(entity_names)

    for e in entity_names
        add_rule!(g, :(Val = $e))
    end

    for c in constants
        add_rule!(g, :(Val = $c))
    end

    original_rules_domain = BitVector(zeros(length(g.rules)))
    original_rules_domain[[1:n_original_rules...]] .= true
    entity_domain = BitVector(zeros(length(g.rules)))
    entity_domain[[n_original_rules+1:n_original_rules+n_entities...]] .= true
    constants_domain = .~(entity_domain .| original_rules_domain)

    # +, *, min, max, are all commutative
    domain = BitVector(zeros(length(g.rules)))
    @. domain[[1, 4:6...]] = true
    template_tree = DomainRuleNode(domain, [VarNode(:a), VarNode(:b)])
    order = [:a, :b]

    addconstraint!(g, Ordered(template_tree, order))

    # Forbid same arguments for 2-argument functions
    domain = BitVector(zeros(length(g.rules)))
    @. domain[length(g.childtypes)==2] = true
    template_tree = DomainRuleNode(domain, [VarNode(:a), VarNode(:a)])

    addconstraint!(g, Forbidden(template_tree))

    # Forbid Ceil and Floor from including an entity or constant directly
    domain = BitVector(zeros(length(g.rules)))
    domain[[n_original_rules+1:length(g.rules)...]] .= true

    entities_consts = DomainRuleNode(domain)

    domain = BitVector(zeros(length(g.rules)))
    domain[[7, 8]] .= true

    template_tree = DomainRuleNode(domain, [entities_consts])

    addconstraint!(g, Forbidden(template_tree))

    # Forbid ceil(floor(x)) and vice-versa
    ceil_or_floor = BitVector(zeros(length(g.rules)))
    ceil_or_floor[[7, 8]] .= true
    template_tree =
        DomainRuleNode(ceil_or_floor, [DomainRuleNode(ceil_or_floor, [VarNode(:a)])])

    addconstraint!(g, Forbidden(template_tree))

    # Forbid constants as numerator of /
    addconstraint!(
        g,
        Forbidden(RuleNode(3, [DomainRuleNode(constants_domain), VarNode(:a)])),
    )

    # Force programs to reference at least one entity
    addconstraint!(g, ContainsSubtree(DomainRuleNode(entity_domain)))

    # Forbid programs to add or subtract 0
    # zero_index = only(findall(g.rules .== (:(0),)))
    # add_subtract_domain = (g.rules .== (:(Val + Val),)) .| (g.rules .== (:(Val - Val),))
    # addconstraint!(g, Forbidden(DomainRuleNode(add_subtract_domain, [VarNode(:a), RuleNode(zero_index)])))

    # Forbid programs to multiply by 0 or 1
    zero_one_domain = (g.rules .== (:(0),)) .| (g.rules .== (:(1),))
    multiply_index = only(findall((g.rules .== (:(Val * Val),))))
    addconstraint!(
        g,
        Forbidden(RuleNode(multiply_index, [VarNode(:a), DomainRuleNode(zero_one_domain)])),
    )

    # Forbid division by 0 or 1
    zero_domain = (g.rules .== (:(0),)) .| (g.rules .== (:(1),))
    division_index = only(findall((g.rules .== (:(Val / Val),))))
    addconstraint!(
        g,
        Forbidden(RuleNode(division_index, [VarNode(:a), DomainRuleNode(zero_domain)])),
    )

    # Forbid min and max
    # min_max_domain = (g.rules .== (:(Min(Val, Val)),)) .| (g.rules .== (:(Max(Val, Val)),))

    # addconstraint!(g, Forbidden(DomainRuleNode(min_max_domain, [VarNode(:a), VarNode(:b)])))

    # Forbid both constants for 2-argument functions
    domain = BitVector(zeros(length(g.rules)))
    @. domain[length(g.childtypes)==2] = true
    template_tree = DomainRuleNode(
        domain,
        [DomainRuleNode(constants_domain), DomainRuleNode(constants_domain)],
    )

    addconstraint!(g, Forbidden(template_tree))

    return g
end

# ╔═╡ 5aebfdef-39d4-431e-826b-3039c95af013
grammar = build_qn_grammar(entity_names, [1])

# ╔═╡ 21ebebde-1794-47e2-a3cb-d1b78bff2c6e
function make_iter()
    return Herb.BFSIterator(grammar, :Val; max_depth = 3)
end

# ╔═╡ fcb30d9c-ca63-4a9d-8b64-a178fdba50a7
total_number_progs_possible = begin
    iter = make_iter()
    length(iter)
end

# ╔═╡ e94f29d0-ea06-4678-86b4-3481db701c9d
function Synth.synth_biodivine(
    problem,
    iterator,
    grammar,
    max_iterations,
    evaluator,
    vertex_names,
)
    exprs_and_scores = []

    for (i, ex) in enumerate(iterator)
        if i % 100000 == 0
            @info "$i iterations, problem $(problem.name)"
        end

        expr = rulenode2expr(ex, grammar)

        sat_examples = nothing
        try
            sat_examples = evaluator(problem, expr, vertex_names)
        catch e
            @error "Problem evaluating: Problem name $(problem.name), expr: $expr, i: $i."
            rethrow(e)
        end

        if isnothing(sat_examples)
            push!(exprs_and_scores, (expr, nothing, nothing, i))
            # if all examples worked in at least one direction
        elseif sum(all.(==(false), sat_examples)) == 0
            score = sum(count.(sat_examples)) / (2 * length(problem.examples))
            push!(exprs_and_scores, (expr, score, sat_examples, i))
        end

        if i > max_iterations
            @warn "Maximum iterations reached"
            break
        end
    end

    return exprs_and_scores
end

# ╔═╡ 938bcef0-2e9d-43bf-9886-c012034453dc
function interpret_qn(
    e,# ::Union{AbstractString,Integer,Expr,Atom},
    qn_state, #::AbstractVector{<:Integer},
    vertex_names, #::AbstractVector{<:AbstractString},
)
    state_map = Dict(zip(vertex_names, deepcopy(qn_state)))

    _int(e) = @match e begin
        ::AbstractString => state_map[e]
        ::Atom => state_map[e]
        ::Integer => e
        ::Symbol => state_map[string(e)]
        :($v1 + $v2) => _int(v1) + _int(v2)
        :($v1 - $v2) => _int(v1) - _int(v2)
        :($v1 / $v2) => _int(v1) / _int(v2)
        :($v1 * $v2) => _int(v1) * _int(v2)
        :(Min($v1, $v2)) => min(_int(v1), _int(v2))
        :(Max($v1, $v2)) => max(_int(v1), _int(v2))
        :(Ceil($v)) => ceil(_int(v))
        :(Floor($v)) => floor(_int(v))
        _ => error("Unhandled Expr in `interpret`: $e, $(typeof(e))")
    end

    return _int(e)
end

# ╔═╡ 62e4af8c-b1cc-428b-981c-f5600f65b714
function Synth.evaluate_qn(problem::UndirectedProblem, expr, vertex_names)
    sat_examples = BitVector[]
    vertex_index = only(findall(==(problem.name), vertex_names))

    function _eval_1_dir(in, out)
        res = interpret_qn(expr, in[:state], vertex_names)
        expected = out[:state][vertex_index]
        success = expected == res
        return success
    end

    for example ∈ problem.examples
        success_direction1 = _eval_1_dir(example.data1, example.data2)
        success_direction2 = _eval_1_dir(example.data2, example.data1)

        success = BitVector([success_direction1, success_direction2])

        push!(sat_examples, success)
    end

    return sat_examples
end

# ╔═╡ 3f2f2fe4-3c84-4bf0-ba7f-8168f5d840bf
results =
    synth_biodivine.(
        problems,
        (make_iter(),),
        (grammar,),
        (10000,),
        (evaluate_qn,),
        (string.(entity_names),),
    )

# ╔═╡ 5bfbfb20-cfb3-40d4-b707-e737f527402a
length.(results)

# ╔═╡ a32ee36a-535f-44ed-997f-7d887a4e2345
n_programs_per_entity =
    ["$name → $num" for (name, num) in zip(entity_names, length.(results))]

# ╔═╡ 64eeefec-9129-4f07-947f-73d611ee6c1c
md"""
### Summary Example

- Unique states (sampled): $(length(states))
- State transition pairs (Hamming distance 1): $(length(unique_transitions))
- \# of functions possible (max-depth: 3): $total_number_progs_possible
- \# of functions that satisfy the transitions: $(join(n_programs_per_entity, ", ", ", and "))
"""

# ╔═╡ 1054aa3b-4675-4054-8eb9-1ff931dcbda6
md"""
## Notebook Setup
"""

# ╔═╡ 00383472-8b56-4504-9f9f-2b2a737e7fb4
TableOfContents(title = "26/03/25")

# ╔═╡ bd4c5a4d-e23d-49e6-82f4-3a21f9f27119
html"""
<style>
	.gone {
		color: white;
	}
	.light {
		color: #818589;
	}
	.verylight {
		color: #E5E4E2;
	}
	.noborder {
		border-bottom: none;

	}
	#titlebox {
		padding-top: 4em;
		padding-bottom: 4em;
	}
	#titlebox p {
		line-height: 0.85em;
		font-size: 2.2rem;
		font-weight: 700;
		font-feature-settings:"lnum","pnum";
		color:var(--pluto-output-h-color);
		margin-block:1rem 0;
		font-family:Vollkorn,Palatino,Georgia,serif;
		font-weight:600;
		line-height:1.25em
	}
</style>
"""

# ╔═╡ Cell order:
# ╟─fa93f89e-05ab-11f0-2dfe-f1e019d9bfe8
# ╟─a1718e12-bfdf-44fe-a930-c9131e64d144
# ╠═3e8e48cc-790c-4a18-990a-637372d432d2
# ╠═ef9ea3aa-1022-409e-8b6e-d79e0455bfc8
# ╠═f00faa20-d261-433d-908e-8047b5a5d45a
# ╠═64eeefec-9129-4f07-947f-73d611ee6c1c
# ╠═94d4c053-c02e-4a07-93b2-63438759acb8
# ╠═754c499a-28e3-42fb-bed3-e466ed1c7393
# ╠═cd238a3a-d6a3-464b-a249-d2e66236ee50
# ╠═2cf1d0f3-5f6f-4fd7-ac97-9072f25f9917
# ╠═3f2f2fe4-3c84-4bf0-ba7f-8168f5d840bf
# ╠═5bfbfb20-cfb3-40d4-b707-e737f527402a
# ╠═a32ee36a-535f-44ed-997f-7d887a4e2345
# ╠═911de256-b75e-4503-9702-c70e70be5779
# ╠═5aebfdef-39d4-431e-826b-3039c95af013
# ╠═fcb30d9c-ca63-4a9d-8b64-a178fdba50a7
# ╠═21ebebde-1794-47e2-a3cb-d1b78bff2c6e
# ╠═d4604287-fde2-4fc9-961b-4505e8210551
# ╠═426f51b8-c9ec-42e9-8d21-9573183f48f4
# ╟─cdc9908c-d858-4cee-ac08-2b135e8aabd2
# ╟─f9e3c41e-1ab9-4a58-aaad-5c97c888728c
# ╟─48bf71ae-ca36-40aa-a65f-e7eb37953058
# ╟─e6fdb952-424a-492f-b9a4-01984a4824bb
# ╟─e94f29d0-ea06-4678-86b4-3481db701c9d
# ╟─938bcef0-2e9d-43bf-9886-c012034453dc
# ╟─62e4af8c-b1cc-428b-981c-f5600f65b714
# ╟─1054aa3b-4675-4054-8eb9-1ff931dcbda6
# ╠═00383472-8b56-4504-9f9f-2b2a737e7fb4
# ╠═bd4c5a4d-e23d-49e6-82f4-3a21f9f27119
# ╠═b6578081-a6fe-4637-903e-4435f7e6c749
# ╠═d03d06ee-5614-4fdd-889d-48c8710b261c
