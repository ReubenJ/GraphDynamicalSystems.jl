import DynamicalSystemsBase: get_state, set_state!

using AbstractTrees: Leaves
using DynamicalSystemsBase: ArbitrarySteppable, current_parameters, initial_state
using HerbConstraints: addconstraint!, DomainRuleNode, VarNode, Ordered, Forbidden
using HerbCore: AbstractGrammar, RuleNode, get_rule
using HerbGrammar: add_rule!, rulenode2expr, @csgrammar
using HerbSearch: rand
using MLStyle: @match
using MetaGraphsNext: MetaGraph, SimpleDiGraph, add_edge!, nv, labels
import SciMLBase
using StaticArrays: MVector
using SoleLogics: Atom, value

const base_qn_grammar = @csgrammar begin
    Val = Val + Val
    Val = Val - Val
    Val = Val / Val
    Val = Val * Val
    Val = Min(Val, Val)
    Val = Max(Val, Val)
    Val = Ceil(Val)
    Val = Floor(Val)
end

const default_qn_constants = [2]

"""
    $(TYPEDSIGNATURES)

Builds a grammar based on the base QN grammar adding `entity_names` and `constants`
to the grammar.

Four constraints are currently included

1. removing symmetry due to commutativity of `+`/`*`/`min`/`max`
2. forbidding same arguments of two argument functions
3. forbidding trivial inputs (consts and entity values) to `floor`/`ceil`
4. forbidding `ceil(floor(_))` and `floor(ceil(_))`

"""
function build_qn_grammar(entity_names, constants = default_qn_constants)
    g = deepcopy(GraphDynamicalSystems.base_qn_grammar)

    for e in entity_names
        add_rule!(g, :(Val = $e))
    end

    for c in constants
        add_rule!(g, :(Val = $c))
    end

    add_rule!(g, :(Start = Val))

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
    n_original_rules = length(GraphDynamicalSystems.base_qn_grammar.rules)
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

    return g
end

"""
    $(TYPEDSIGNATURES)
"""
function update_functions_to_network(
    update_functions::AbstractDict{Symbol,<:Any},
    grammar::AbstractGrammar,
)
    network = MetaGraph(
        SimpleDiGraph();
        label_type = Symbol,
        vertex_data_type = Union{Symbol,Expr,Int,Atom},
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
struct QualitativeNetwork{N,C}
    "Graph containing the topology and target functions of the network"
    graph::MetaGraph
    "State of the network"
    state::MVector{C,Int}
    "The maximum activation level/state value of any component"
    N::Int

    function QualitativeNetwork(g, s, N)
        if any(s .> N)
            error("All values in state must be <= N (N=$N)")
        end

        return new{N,length(s)}(g, s, N)
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

function _get_component_index(qn::QN, component)
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
function get_state(qn::QN, component)
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
        :($v1 * $v2) => interpret(v1, qn) * interpret(v2, qn)
        :(Min($v1, $v2)) => min(interpret(v1, qn), interpret(v2, qn))
        :(Max($v1, $v2)) => max(interpret(v1, qn), interpret(v2, qn))
        :(Ceil($v)) => ceil(interpret(v, qn))
        :(Floor($v)) => floor(interpret(v, qn))
        _ => error("Unhandled Expr in `interpret`: $e")
    end
end
interpret(e::Atom, qn::QN) = get_state(qn, Symbol(value(e)))

"""
    $(TYPEDSIGNATURES)

Returns the limited value of `next_value` which is at most 1 different than `prev_value`.

It is also never negative, or larger than `N`.
"""
function limit_change(prev_value::Integer, next_value::Integer, N::Integer)
    if next_value > prev_value
        limited_value = min(prev_value + 1, N)
    elseif next_value < prev_value
        limited_value = max(prev_value - 1, 0)
    else
        limited_value = next_value
    end

    return limited_value
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
    new_state = isnan(new_state) ? 0 : new_state
    new_state = isinf(new_state) ? max_level(qn) : new_state
    limited_state = limit_change(old_state, floor(Int, new_state), max_level(qn))
    set_state!(qn, c_i, limited_state)
end

extract_state(model::QN) = model.state
extract_parameters(model::QN) = model.graph
reset_model!(model::QN, u, _) = model.state .= u

function SciMLBase.reinit!(
    ds::ArbitrarySteppable{<:AbstractVector{<:Real},<:QualitativeNetwork},
    u::AbstractVector{<:Real} = initial_state(ds);
    p = current_parameters(ds),
    t0 = 0, # t0 is not used but required for downstream.
)
    ds.reinit(ds.model, u, p)
    ds.t[] = 0
    return ds
end

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
