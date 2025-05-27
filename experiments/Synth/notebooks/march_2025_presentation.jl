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
	import MetaGraphsNext
	using SoleLogics: value, Atom
	# using ProgressMeter, DataFrames, HerbSearch, Random
	using MetaGraphsNext: labels
	# using Statistics: quantile
	# using DynamicalSystems
	using Clingo_jll
	using Plots
	using Graphs
	using GraphRecipes
	using PlutoUI
	# using Herb
	using SoleLogics
	using MLStyle
	import HerbConstraints.pattern_match
	using HerbConstraints: PatternMatchResult, PatternMatchSuccess, PatternMatchSoftFail, PatternMatchHardFail, PatternMatchSuccessWhenHoleAssignedTo
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

Given:

- A *grammar* for target functions (arithmetic for QNs, logical operators for BNs)
  - Includes a set of *genes/proteins*
- A *specification*, which is one or both of
  - *Longitudinal data*: state transition pairs and steady states
  - *Perturbation data*: fixed values for a subset of genes/proteins, and steady states


Find:

- A set of *target functions* for each gene/protein
- Satisfying combinations of target functions must match the specification's
  - Steady states (under perturbation as well, if given)
  - State transition pairs, if given
"""

# ╔═╡ 1b53d4e4-fb36-4c8a-9e35-55c3832f0005
md"""
### Formulation Examples

!!! tip "Target Functions"
	Set of functions, one per gene/protein
	```julia
	Coup_fti = ...
	Emx2 = Coup_fti / (1 - Fgf8)
	Fgf8 = ...
	```
	When assembled into a complete model (QN, for example), a satisfying set of functions should match the specification (longitudinal and/or perturbation)
"""

# ╔═╡ ef9ea3aa-1022-409e-8b6e-d79e0455bfc8
md"""
## ✓ What we have

A synthesis pipeline that starts either from

- An existing model, sampling longitudinal data, and steady state(s) from it
- Longitudinal data and steady state(s) directly

and synthesizes a set of target functions whose combination matches the longitundal data and steady states.

The pipeline:

1. Constructs a grammar for the problem
2. Enumerates candidate functions from the grammar
3. Checks candidate functions against the longitudinal data (state transition pairs)
4. Uses the result to select possible combinations of target functions that have the specified steady state(s)
"""

# ╔═╡ f00faa20-d261-433d-908e-8047b5a5d45a
md"""
### Walk through

1. The model we start with
2. Sampling data from it
3. Synthesizing possible target functions
4. Combining to a complete model
"""

# ╔═╡ df82d6bc-2c8b-48ec-b4fc-7d0c0ce9d7d3
md"""
#### Original Model
"""

# ╔═╡ f38f30d0-c875-4f1a-819d-a4b20cb382ff
md"""
!!! info ""
	Giacomantonio CE, Goodhill GJ (2010) A Boolean Model of the Gene Regulatory Network Underlying Mammalian Cortical Area Development. PLoS Comput Biol 6(9): e1000936. [https://doi.org/10.1371/journal.pcbi.1000936](https://doi.org/10.1371/journal.pcbi.1000936)
"""

# ╔═╡ a03aab2a-8af1-4c0c-aae7-ef34b96c1702
begin
	n_trajectories = 10
	length_trajectory = 10
	max_iterations = 50000
	max_depth = 3
end

# ╔═╡ 4710d9e8-7781-4b01-bec5-c8e30219b5c2
s1 = [0, 0, 1, 1, 1]

# ╔═╡ 648ddc71-f6f3-44ac-b44a-8d0f1a5ed958
s2 = [1, 0, 1, 1, 1]

# ╔═╡ fd621392-67d6-4b3d-beb7-04c963f5b993
searching = Set([s1, s2])

# ╔═╡ 9dc68992-7f48-4ed7-af1e-61bc6d693f8c
md"""
### Combining Local Solutions

→ Other notebook
"""

# ╔═╡ d4604287-fde2-4fc9-961b-4505e8210551
md"""
## ❗ What we're missing

- Current models will definitely enter all steady states, but might enter other steady states outside of the specification
  - Next step is to verify this
"""

# ╔═╡ 426f51b8-c9ec-42e9-8d21-9573183f48f4
md"""
## ❓ Questions

- When *you* use BMA, what do you verify?
  - If something is wrong, how do you use the outcome of the verification to fix it?
- What does model stabilization mean to you?
  - Do oscillating states count?
- Can we assume we have all steady states present in the data?
- When working with perturbation data, what can we start from as a target function?
- Any patterns of target functions that you often see?
- Current approach can create “correct” models that visit states that were not in the data
  - Do we want to minimize this?
  - For example, which one to choose?
    - We have a simple model that visits many states not in the data, but has the correct dynamics
    - We have a complex model that stays within the states in the data
- Which specific papers to re-do?

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
	model_df = collect_results(datadir("src_parsed", "biodivine_benchmark_as_metagraphs"););
	path2id = path -> parse(Int, splitext(basename(path))[1])
	model_df.ID = path2id.(model_df.path)
	model007 = only(model_df[model_df.ID .== 7, :metagraph_model])
end

# ╔═╡ 86faab19-6712-4d7e-aeb8-1ea1febc3b97
original_model_plot = plot(reverse(model007.graph); names=labels(model007) .|> string .|> (x -> x[39:end]), method=:shell, self_edge_size=0.12, nodecolor=:white, nodeshape=:circle)

# ╔═╡ 9551231b-753d-4958-8444-23cbdae1146e
savefig(original_model_plot, "original_model_plot.png")

# ╔═╡ fe8fbd0b-c384-4d93-ab5a-230d67ec6f8f
functions007 = Pair.(labels(model007) .|> string .|> (x -> x[39:end]), (labels(model007) .|> (x -> model007[x]) .|> string .|> (x -> x[26:end]) .|> (x -> replace(x, "v_" => "")))) |> Dict;

# ╔═╡ ad6776d9-6fec-467a-a75e-c0ec86afdaf9
md"""
$(Markdown.Table([["Gene", "Target Function"], [[k, v] for (k, v) in functions007]...], [:l, :l]))
"""

# ╔═╡ 94d4c053-c02e-4a07-93b2-63438759acb8
begin
	trajectories = []
	for i in 1:n_trajectories
		abn7 = BooleanNetworks.abn(model007; seed=i)
		data = gather_bn_data(abn7, length_trajectory)
		push!(trajectories, data)
	end
	states = trajectories |> Iterators.flatten |> unique
end

# ╔═╡ 2abbdd40-8e4e-49d6-ad5a-ecfa46c588d8
for s in states
	print("[], ")
	for x in s
		print("[$x], ")
	end
	println()
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

# ╔═╡ b21cb05c-f72e-411f-a2fd-b675e84e23b7
md"""
### Formulation Examples

$(Markdown.Admonition("tip", "Specification: Longitudinal Data", [
	Markdown.Paragraph("State transition pairs such as"),
	Markdown.Code("julia", join(string.(io_pairs[1:3]), "\n") * "\n..."),
	Markdown.Paragraph("With one or more of these states marked as steady"),
]))

!!! warning "Specification: Perturbation Data"
	Fixed value, and a corresponding steady state

	```julia
	[□, □, □, 1, □] → [0, 0, 1, 1, 0]
	```

	`□`: unfixed value

"""

# ╔═╡ 282c25ec-8847-4ca9-bee9-7b9d0874c2b8
begin
	state_space = MetaGraphsNext.MetaGraph(SimpleGraph(), label_type=AbstractVector)
	add_vertex!.((state_space,), states)
	[add_edge!(state_space, x[1], x[2]) for x in io_pairs]
end

# ╔═╡ 7a67e9fe-7bf9-4117-8e00-10afcee2f239
state_space_plot = plot(state_space.graph, curves=false, method=:stress)

# ╔═╡ f2c73222-3c36-415a-97ae-b8a1a15b574f
savefig(state_space_plot, "state_space.png")

# ╔═╡ 91f44e97-bbac-413d-8331-dc1328f96f89
md"""
### Converting to IO Pairs

Then, we convert to input/output pairs to check the target functions. In this case, we are assuming an asynchronous update schedule, so every pair of states that is a hamming distance of 1 apart becomes an example.

$(Markdown.Code("julia", join(string.(io_pairs[1:3]), "\n") * "\n..."))

"""

# ╔═╡ cd238a3a-d6a3-464b-a249-d2e66236ee50
unique_transitions = io_pairs .|> Set |> unique .|> collect

# ╔═╡ e4732348-0188-4fb0-a0cd-e1888ec5f9fd
state_string = "state(1..$(length(states)))."

# ╔═╡ 911de256-b75e-4503-9702-c70e70be5779
entity_names = model007 |> labels .|> value .|> (x -> replace(x, "v_" => "")) .|> Symbol

# ╔═╡ d42cbcbd-5990-4818-9edb-02d631486667
md"""
### Sampling Longitudinal Data

Data comes as a set of states. Each row here is a state.

$(Markdown.Table([["Gene", string.(entity_names)...], [vcat("", s) for (i, s) in enumerate(states)]...], [:l, :l, :l, :l, :l, :l]))

"""

# ╔═╡ 2cf1d0f3-5f6f-4fd7-ac97-9072f25f9917
problems = [
	UndirectedProblem(
		string(entity_names[i]),
		[
			UndirectedExample(
				Dict(:state => t[1]),
				Dict(:state => t[2])
			) for t in unique_transitions if t[1][i] != t[2][i]
		]
	) for i in 1:length(entity_names)
]

# ╔═╡ 8e075539-3c74-4506-9191-74c0c2944d94
[Set([x.data1[:state], x.data2[:state]]) for x in problems[1].examples]

# ╔═╡ 5ccb2ec7-b0ee-48de-9acc-a44de5ddb57d
problems[1].examples

# ╔═╡ 9fece869-b636-410e-a480-9f5fcbec5a75
entity_string = "entity($(join(entity_names, ";")))."

# ╔═╡ a6657d7d-0bc3-4c83-bbef-c43e519d6cb4
base_grammar_string = let io = IOBuffer()
	Base.show(io, GraphDynamicalSystems.base_qn_grammar)
	String(take!(io))
end

# ╔═╡ 9925d04e-e042-4d14-ad37-bba85aa54a34
md"""
### Formulation Examples

$(Markdown.Admonition("info", "Grammar", [
	Markdown.Paragraph("QN grammar, matching the BMA tool"),
	Markdown.Code("julia", base_grammar_string),
	Markdown.Paragraph("In a full grammar, we also have `Val = Gene/Protein` for each one in the problem"),
]))
"""

# ╔═╡ e6fdb952-424a-492f-b9a4-01984a4824bb
function build_qn_grammar(
    entity_names,
    constants = default_qn_constants,
)
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
	entity_domain[[n_original_rules+1:n_original_rules + n_entities...]] .= true
	constants_domain = .~(entity_domain .| original_rules_domain)

    # +, *, min, max, are all commutative
	domain = BitVector(zeros(length(g.rules)))
	@. domain[[1, 4:6...]] = true
    template_tree = DomainRuleNode(domain, [VarNode(:a), VarNode(:b)])
    order = [:a, :b]

    addconstraint!(g, Ordered(template_tree, order))

    # Forbid same arguments for 2-argument functions
	domain = BitVector(zeros(length(g.rules)))
	@. domain[length(g.childtypes) == 2] = true
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
	addconstraint!(g, Forbidden(RuleNode(3, [
		DomainRuleNode(constants_domain),
		VarNode(:a)
	])))

	# Force programs to reference at least one entity
	addconstraint!(g, ContainsSubtree(DomainRuleNode(entity_domain)))

	# Forbid programs to add or subtract 0
	# zero_index = only(findall(g.rules .== (:(0),)))
	# add_subtract_domain = (g.rules .== (:(Val + Val),)) .| (g.rules .== (:(Val - Val),))
	# addconstraint!(g, Forbidden(DomainRuleNode(add_subtract_domain, [VarNode(:a), RuleNode(zero_index)])))

	# Forbid programs to multiply by 0 or 1
	zero_one_domain = (g.rules .== (:(0),)) .| (g.rules .== (:(1),))
	multiply_index = only(findall((g.rules .== (:(Val * Val),))))
	addconstraint!(g, Forbidden(RuleNode(multiply_index, [VarNode(:a), DomainRuleNode(zero_one_domain)])))

	# Forbid division by 0 or 1
	zero_domain = (g.rules .== (:(0),)) .| (g.rules .== (:(1),))
	division_index = only(findall((g.rules .== (:(Val / Val),))))
	addconstraint!(g, Forbidden(RuleNode(division_index, [VarNode(:a), DomainRuleNode(zero_domain)])))
	
	# Forbid min and max
	# min_max_domain = (g.rules .== (:(Min(Val, Val)),)) .| (g.rules .== (:(Max(Val, Val)),))
	
	# addconstraint!(g, Forbidden(DomainRuleNode(min_max_domain, [VarNode(:a), VarNode(:b)])))

	# Forbid both constants for 2-argument functions
	domain = BitVector(zeros(length(g.rules)))
	@. domain[length(g.childtypes) == 2] = true
    template_tree = DomainRuleNode(domain, [
		DomainRuleNode(constants_domain),
		DomainRuleNode(constants_domain)
	])

	addconstraint!(g, Forbidden(template_tree))

	# * by 1

    return g
end

# ╔═╡ 5aebfdef-39d4-431e-826b-3039c95af013
grammar = build_qn_grammar(
	entity_names,
	[1]
)

# ╔═╡ 21ebebde-1794-47e2-a3cb-d1b78bff2c6e
function make_iter()
	return Herb.BFSIterator(grammar, :Val; max_depth)
end

# ╔═╡ fcb30d9c-ca63-4a9d-8b64-a178fdba50a7
total_number_progs_possible = begin
	iter = make_iter()
	length(iter)
end

# ╔═╡ f8e7784b-e706-4ac8-8373-f60566a30ddc
grammar_string = let io = IOBuffer()
	Base.show(io, grammar)
	String(take!(io))
end

# ╔═╡ cb24a482-5323-4a3d-b03b-6a8d4b9a6183
md"""
### Enumerating Candidate Functions

From our grammar

$(Markdown.Code("julia", grammar_string))

We enumerate all programs up to a certain depth (which is $total_number_progs_possible in total, in this case)

We apply a number of constraints in the enumeration process to prune many possible functions.

- +, *, min, max, are all commutative
- Forbid same arguments for 2-argument functions
- Forbid division by 1
- Forbid only constants for 2-argument functions
- Forbid `ceil` and `floor` from including a gene or constant directly
- Forbid `ceil(floor(x))` and vice-versa
- Forbid constants as numerator of /

"""

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
    vertex_names #::AbstractVector{<:AbstractString},
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
results = synth_biodivine.(
	problems,
	(make_iter(),),
	(grammar,),
	(max_iterations,),
	(evaluate_qn,),
	(string.(entity_names),)
)

# ╔═╡ ca878159-a262-46f4-a012-03b6f3ee3ae2
[r for r in results[1] if r[3][1] == [false, true]][begin:begin+20] .|> (x -> x[1]) .|> string .|> (x -> println(x))

# ╔═╡ c1478d13-7168-4dc0-ab2a-5e4e792f910d
length(results[1]) - 20

# ╔═╡ 06002e18-f6b4-4e69-aabf-7b8537f03c3c
[r for r in results[1] if r[3][1] == [false, true]][begin:begin+20] .|> (x -> x[1]) .|> string .|> (x -> replace(
	x,
	"*" => "times",
	"Min" => "\"Min\"",
	"Max" => "\"Max\"",
	(string.(entity_names) .=> ["\"$e\"" for e in entity_names])...
)) .|> (x -> println(x))

# ╔═╡ 1473d4f2-4665-43e9-91f7-5bd6e9f088cb
println.(map(x -> string(x[1]), results[1])[1:100])

# ╔═╡ 5bfbfb20-cfb3-40d4-b707-e737f527402a
length.(results)

# ╔═╡ a32ee36a-535f-44ed-997f-7d887a4e2345
n_programs_per_entity = ["$name → $num" for (name, num) in zip(entity_names, length.(results))]

# ╔═╡ 64eeefec-9129-4f07-947f-73d611ee6c1c
md"""
### Summary Example

- Unique states (sampled): $(length(states))
- State transition pairs (Hamming distance 1): $(length(unique_transitions))
- \# of functions possible (max-depth: 3): $total_number_progs_possible
- \# of functions that satisfy the transitions: $(join(n_programs_per_entity, ", ", ", and "))
"""

# ╔═╡ a31cfabd-8894-42f2-95d7-201ba06a853d
n_programs_foreach_entity = ["$num for $name" for (name, num) in zip(entity_names, length.(results))]

# ╔═╡ f58351c9-f49d-4a0a-9137-06d8c68d6251
md"""
### Check against IO Examples

With candidate programs, and IO examples, we can check which candidate programs correctly transform input to output for each example.

This reduces the number of candidate functions for each entity to $(join(n_programs_foreach_entity, ", ", ", and ")).

This step also gives us the information for which *direction* each candidate function works in
"""

# ╔═╡ edd72405-6889-4cbc-9b5f-4378130b0d31
sol_ids = [results[i] .|> (x -> x[4]) for i in eachindex(results)]

# ╔═╡ 1054aa3b-4675-4054-8eb9-1ff931dcbda6
md"""
## Notebook Setup
"""

# ╔═╡ 00383472-8b56-4504-9f9f-2b2a737e7fb4
TableOfContents(title="26/03/25", depth=2)

# ╔═╡ bd4c5a4d-e23d-49e6-82f4-3a21f9f27119
html"""
<style>
	.gone {
		opacity: 0%;
	}
	.light {
		opacity: 25%;
	}
	.verylight {
		opacity: 10%;
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
# ╟─3e8e48cc-790c-4a18-990a-637372d432d2
# ╟─9925d04e-e042-4d14-ad37-bba85aa54a34
# ╟─b21cb05c-f72e-411f-a2fd-b675e84e23b7
# ╟─1b53d4e4-fb36-4c8a-9e35-55c3832f0005
# ╟─ef9ea3aa-1022-409e-8b6e-d79e0455bfc8
# ╟─f00faa20-d261-433d-908e-8047b5a5d45a
# ╟─df82d6bc-2c8b-48ec-b4fc-7d0c0ce9d7d3
# ╟─86faab19-6712-4d7e-aeb8-1ea1febc3b97
# ╟─9551231b-753d-4958-8444-23cbdae1146e
# ╟─ad6776d9-6fec-467a-a75e-c0ec86afdaf9
# ╟─f38f30d0-c875-4f1a-819d-a4b20cb382ff
# ╟─fe8fbd0b-c384-4d93-ab5a-230d67ec6f8f
# ╠═d42cbcbd-5990-4818-9edb-02d631486667
# ╠═282c25ec-8847-4ca9-bee9-7b9d0874c2b8
# ╠═2abbdd40-8e4e-49d6-ad5a-ecfa46c588d8
# ╠═7a67e9fe-7bf9-4117-8e00-10afcee2f239
# ╠═f2c73222-3c36-415a-97ae-b8a1a15b574f
# ╟─91f44e97-bbac-413d-8331-dc1328f96f89
# ╟─cb24a482-5323-4a3d-b03b-6a8d4b9a6183
# ╟─f58351c9-f49d-4a0a-9137-06d8c68d6251
# ╟─64eeefec-9129-4f07-947f-73d611ee6c1c
# ╠═a03aab2a-8af1-4c0c-aae7-ef34b96c1702
# ╠═21ebebde-1794-47e2-a3cb-d1b78bff2c6e
# ╠═94d4c053-c02e-4a07-93b2-63438759acb8
# ╠═754c499a-28e3-42fb-bed3-e466ed1c7393
# ╠═cd238a3a-d6a3-464b-a249-d2e66236ee50
# ╠═2cf1d0f3-5f6f-4fd7-ac97-9072f25f9917
# ╠═3f2f2fe4-3c84-4bf0-ba7f-8168f5d840bf
# ╠═4710d9e8-7781-4b01-bec5-c8e30219b5c2
# ╠═648ddc71-f6f3-44ac-b44a-8d0f1a5ed958
# ╠═fd621392-67d6-4b3d-beb7-04c963f5b993
# ╠═8e075539-3c74-4506-9191-74c0c2944d94
# ╠═5ccb2ec7-b0ee-48de-9acc-a44de5ddb57d
# ╠═ca878159-a262-46f4-a012-03b6f3ee3ae2
# ╠═c1478d13-7168-4dc0-ab2a-5e4e792f910d
# ╠═06002e18-f6b4-4e69-aabf-7b8537f03c3c
# ╠═1473d4f2-4665-43e9-91f7-5bd6e9f088cb
# ╠═5bfbfb20-cfb3-40d4-b707-e737f527402a
# ╠═a32ee36a-535f-44ed-997f-7d887a4e2345
# ╠═a31cfabd-8894-42f2-95d7-201ba06a853d
# ╠═911de256-b75e-4503-9702-c70e70be5779
# ╠═5aebfdef-39d4-431e-826b-3039c95af013
# ╠═fcb30d9c-ca63-4a9d-8b64-a178fdba50a7
# ╠═9dc68992-7f48-4ed7-af1e-61bc6d693f8c
# ╠═9fece869-b636-410e-a480-9f5fcbec5a75
# ╟─e4732348-0188-4fb0-a0cd-e1888ec5f9fd
# ╠═edd72405-6889-4cbc-9b5f-4378130b0d31
# ╟─d4604287-fde2-4fc9-961b-4505e8210551
# ╟─426f51b8-c9ec-42e9-8d21-9573183f48f4
# ╟─cdc9908c-d858-4cee-ac08-2b135e8aabd2
# ╟─f9e3c41e-1ab9-4a58-aaad-5c97c888728c
# ╠═48bf71ae-ca36-40aa-a65f-e7eb37953058
# ╠═a6657d7d-0bc3-4c83-bbef-c43e519d6cb4
# ╠═f8e7784b-e706-4ac8-8373-f60566a30ddc
# ╠═e6fdb952-424a-492f-b9a4-01984a4824bb
# ╟─e94f29d0-ea06-4678-86b4-3481db701c9d
# ╟─938bcef0-2e9d-43bf-9886-c012034453dc
# ╟─62e4af8c-b1cc-428b-981c-f5600f65b714
# ╟─1054aa3b-4675-4054-8eb9-1ff931dcbda6
# ╠═00383472-8b56-4504-9f9f-2b2a737e7fb4
# ╠═b6578081-a6fe-4637-903e-4435f7e6c749
# ╠═d03d06ee-5614-4fdd-889d-48c8710b261c
# ╠═bd4c5a4d-e23d-49e6-82f4-3a21f9f27119
