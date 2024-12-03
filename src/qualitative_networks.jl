import DynamicalSystems: get_state, set_state!

using AbstractTrees: Leaves
using HerbCore: AbstractGrammar, RuleNode, get_rule
using HerbGrammar: @csgrammar, add_rule!, rulenode2expr
using HerbSearch
using MLStyle: @match
using MetaGraphsNext: MetaGraph, SimpleDiGraph, add_edge!, nv

const base_qn_grammar = @csgrammar begin
    # ManyVals = Pos() | Neg()
    Val =
        (Val + Val) |
        (Val - Val) |
        Val / Val |
        # Avg(ManyVals) |
        Min(Val, Val) |
        Max(Val, Val) |
        Ceil(Val) |
        Floor(Val)
end

const default_qn_constants = [2]

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

    return g
end

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

function sample_qualitative_network(entities::AbstractVector{Symbol}, max_eq_depth::Int)
    g = build_qn_grammar(entities, default_qn_constants)
    update_fns = Dict{Symbol,Union{Symbol,Expr,Int}}([
        e => rulenode2expr(rand(RuleNode, g, :Val, max_eq_depth), g) for e in entities
    ])
    graph = update_functions_to_network(update_fns, g)

    return graph
end

function sample_qualitative_network(size::Int, max_eq_depth::Int)
    entities = [Symbol("c$e") for e = 1:size]
    sample_qualitative_network(entities, max_eq_depth)
end

struct QualitativeNetwork
    graph::MetaGraph
    state::AbstractVector{Int}
    N::Int

    function QualitativeNetwork(g, s, N)
        if any(s .> N)
            error("All values in state must be <= N (N=$N)")
        end

        return new(g, s, N)
    end
end

const QN = QualitativeNetwork

function max_level(qn::QN)
    return qn.N
end

function _get_component_index(qn::QN, component::Symbol)
    return findfirst(isequal(component), components(qn))
end

function components(qn::QN)
    return collect(labels(qn.graph))
end

C(qn::QN) = components(qn)

function target_functions(qn::QN)
    return Dict([c => fn for (c, (_, fn)) in qn.graph.vertex_properties])
end

T(qn::QN) = target_functions(qn)

get_state(qn::QN) = qn.state

function get_state(qn::QN, component::Symbol)
    i = _get_component_index(qn, component)
    return qn.state[i]
end

S(qn::QN) = qn.state
S(qn::QN, component::Symbol) = get_state(qn, component)

function _set_state!(qn::QN, component::Symbol, value::Integer)
    i = _get_component_index(qn::QN, component::Symbol)
    qn.state[i] = value
end

function set_state!(qn::QN, component::Symbol, value::Integer)
    if value > max_level(qn)
        error(
            "Value ($value) cannot be larger than the QN's maximum level (N=$(max_level(qn)))",
        )
    end

    _set_state!(qn, component, value)
end

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

function limit_change(prev_value, next_value, N::Int)
    limited_value = 1
    if next_value > prev_value
        return min(prev_value + 1, N + 1)
    elseif next_value < prev_value
        return max(prev_value - 1, 0)
    elseif next_value == prev_value
        return next_value
    end

    return round(Int, limited_value)
end

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

function reset_model!(model::QN, u, _)
    model.state .= u
end

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

function aqn(network::MetaGraph, max_level::Int)
    n_components = nv(network)
    initial_state = rand(0:max_level, n_components)
    return aqn(network, initial_state, max_level)
end
