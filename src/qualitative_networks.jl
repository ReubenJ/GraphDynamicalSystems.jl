import DynamicalSystems: get_state, set_state!

using AbstractTrees: Leaves
using HerbCore: AbstractGrammar, RuleNode, get_rule
using HerbGrammar: add_rule!, rulenode2expr, @csgrammar
using HerbConstraints: addconstraint!, DomainRuleNode, VarNode, Ordered, Forbidden
using HerbSearch
using MLStyle: @match
using MetaGraphsNext: MetaGraph, SimpleDiGraph, add_edge!, nv

base_qn_grammar = @csgrammar begin
    Val = Val + Val
    Val = Val - Val
    Val = Val / Val
    Val = Val * Val
    Val = Min(Val, Val)
    Val = Max(Val, Val)
    Val = Ceil(Val)
    Val = Floor(Val)
end

default_qn_constants = [2]

"""
    $(TYPEDSIGNATURES)
"""
function build_qn_grammar(
    entity_names::AbstractVector{Symbol},
    constants::AbstractVector{<:Integer},
)
    g = deepcopy(base_qn_grammar)

    for e in entity_names
        add_rule!(g, :(Val = $e))
    end

    for c in constants
        add_rule!(g, :(Val = $c))
    end

    # +, *, min, max, are all commutative
    template_tree = DomainRuleNode(
        BitVector([
            1,
            0,
            0,
            1,
            1,
            1,
            0,
            0,
            zeros(Int, length(entity_names) + length(constants))...,
        ]),
        [VarNode(:a), VarNode(:b)],
    )
    order = [:a, :b]

    addconstraint!(g, Ordered(template_tree, order))

    # Forbid same arguments for 2-argument functions
    template_tree = DomainRuleNode(
        BitVector([
            1,
            0,
            0,
            1,
            1,
            1,
            0,
            0,
            zeros(Int, length(entity_names) + length(constants))...,
        ]),
        [VarNode(:a), VarNode(:a)],
    )

    addconstraint!(g, Forbidden(template_tree))

    return g
end

"""
    $(TYPEDSIGNATURES)
"""
function update_functions_to_network(
    update_functions::AbstractDict{Symbol,Union{Symbol,Expr,Int}},
    grammar::AbstractGrammar,
)
    network = MetaGraph(
        SimpleDiGraph();
        label_type = Symbol,
        vertex_data_type = Union{Symbol,Expr,Int},
        graph_data = grammar,
    )

    for (e, f) in update_functions
        network[e] = f
    end

    for (e1, f) in update_functions
        input_variables = collect(Leaves(f))
        for e2 in input_variables
            add_edge!(network, e1, e2)
        end
    end

    return network
end

"""
    $(TYPEDSIGNATURES)
"""
function sample_qualitative_network(entities::AbstractVector{Symbol}, max_eq_depth::Int)
    g = build_qn_grammar(entities, default_qn_constants)
    update_fns = Dict{Symbol,Union{Symbol,Expr,Int}}([
        e => rulenode2expr(rand(RuleNode, g, :Val, max_eq_depth), g) for e in entities
    ])
    graph = update_functions_to_network(update_fns, g)

    return graph
end

"""
    $(TYPEDSIGNATURES)
"""
function sample_qualitative_network(size::Int, max_eq_depth::Int)
    entities = [Symbol("c$e") for e = 1:size]
    sample_qualitative_network(entities, max_eq_depth)
end

"""
    $(TYPEDEF)

A qualitative network model as described in
["Qualitative networks: a symbolic approach to analyze biological
signaling networks"](https://doi.org/10.1186/1752-0509-1-4
).

$(FIELDS)

Systems that include the model semantics wrap around this struct
with an [`ArbitrarySteppable`](https://juliadynamics.github.io/DynamicalSystems.jl/stable/tutorial/#DynamicalSystemsBase.ArbitrarySteppable)
from [`DynamicalSystems`](https://juliadynamics.github.io/DynamicalSystems.jl/stable/).
See [`aqn`](@ref) for an example.
"""
struct QualitativeNetwork
    "Graph containing the topology and target functions of the network"
    graph::MetaGraph
    "State of the network"
    state::AbstractVector{Int}
    "The maximum activation level/state value of any component"
    N::Int

    function QualitativeNetwork(g, s, N)
        if any(s .> N)
            error("All values in state must be <= N (N=$N)")
        end

        return new(g, s, N)
    end
end

"""
    $(TYPEDSIGNATURES)

Shorthand for [`QualitativeNetwork`](@ref).
"""
const QN = QualitativeNetwork

"""
    $(TYPEDSIGNATURES)
"""
function max_level(qn::QN)
    return qn.N
end

function _get_component_index(qn::QN, component::Symbol)
    return findfirst(isequal(component), components(qn))
end

"""
    $(TYPEDSIGNATURES)
"""
function components(qn::QN)
    return collect(labels(qn.graph))
end

"""
    $(TYPEDSIGNATURES)
"""
function target_functions(qn::QN)
    return Dict([c => fn for (c, (_, fn)) in qn.graph.vertex_properties])
end

"""
    $(TYPEDSIGNATURES)
"""
get_state(qn::QN) = qn.state

"""
    $(TYPEDSIGNATURES)
"""
function get_state(qn::QN, component::Symbol)
    i = _get_component_index(qn, component)
    return qn.state[i]
end

function _set_state!(qn::QN, component::Symbol, value::Integer)
    i = _get_component_index(qn::QN, component::Symbol)
    qn.state[i] = value
end

"""
    $(TYPEDSIGNATURES)
"""
function set_state!(qn::QN, component::Symbol, value::Integer)
    if value > max_level(qn)
        error(
            "Value ($value) cannot be larger than the QN's maximum level (N=$(max_level(qn)))",
        )
    end

    _set_state!(qn, component, value)
end

"""
    $(TYPEDSIGNATURES)

Interpret target functions from a [`QualitativeNetwork`](@ref).
"""
function interpret(e::Union{Expr,Symbol,Int}, qn::QN)
    @match e begin
        ::Symbol => get_state(qn, e)
        ::Int => e
        :($v1 + $v2) => interpret(v1, qn) + interpret(v2, qn)
        :($v1 - $v2) => interpret(v1, qn) - interpret(v2, qn)
        :($v1 / $v2) => interpret(v1, qn) / interpret(v2, qn)
        :(Min($v1, $v2)) => min(interpret(v1, qn), interpret(v2, qn))
        :(Max($v1, $v2)) => max(interpret(v1, qn), interpret(v2, qn))
        :(Ceil($v)) => ceil(interpret(v, qn))
        :(Floor($v)) => floor(interpret(v, qn))
        _ => error("Unhandled Expr in `interpret`: $e")
    end
end

"""
    $(TYPEDSIGNATURES)
"""
function limit_change(prev_value, next_value, N::Int)
    if next_value > prev_value
        limited_value = min(prev_value + 1, N + 1)
    elseif next_value < prev_value
        limited_value = max(prev_value - 1, 0)
    else
        limited_value = next_value
    end

    return round(Int, limited_value)
end

"""
    $(TYPEDSIGNATURES)
"""
function async_qn_step!(qn::QN)
    vertex_labels = collect(labels(qn.graph))
    c_i = rand(vertex_labels)
    t = target_functions(qn)[c_i]
    old_state = get_state(qn, c_i)
    new_state = interpret(t, qn)
    limited_state = limit_change(old_state, new_state, max_level(qn))
    set_state!(qn, c_i, limited_state)
end

extract_state(model::QN) = model.state
extract_parameters(model::QN) = model.graph
reset_model!(model::QN, u, _) = model.state .= u

"""
    $(TYPEDSIGNATURES)

Construct an asynchronous [`QualitativeNetwork`](@ref) system using the
[`async_qn_step!`](@ref) as a step function.
"""
function aqn(network::MetaGraph, initial_state::AbstractVector{Int}, max_level::Int)
    model = QualitativeNetwork(network, initial_state, max_level)

    return ArbitrarySteppable(
        model,
        async_qn_step!,
        extract_state,
        extract_parameters,
        reset_model!,
        isdeterministic = false,
    )
end

"""
    $(TYPEDSIGNATURES)
"""
function aqn(network::MetaGraph, max_level::Int)
    n_components = nv(network)
    initial_state = rand(0:max_level, n_components)
    return aqn(network, initial_state, max_level)
end
