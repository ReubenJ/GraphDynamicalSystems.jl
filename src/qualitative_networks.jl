using AbstractTrees: Leaves
using HerbCore: AbstractGrammar, AbstractRuleNode, RuleNode, get_rule
using HerbGrammar: @csgrammar, add_rule!
using HerbSearch
using MetaGraphsNext: MetaGraph, SimpleDiGraph, add_edge!
using MLStyle: @match

const base_qn_grammar = @csgrammar begin
    ManyVals = Pos() | Neg()
    Val =
        (Val + Val) |
        (Val - Val) |
        Val / Val |
        Avg(ManyVals) |
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
    update_functions::AbstractDict{Symbol,<:AbstractRuleNode},
    grammar::AbstractGrammar,
)
    network = MetaGraph(
        SimpleDiGraph();
        label_type = Symbol,
        vertex_data_type = AbstractRuleNode,
        graph_data = grammar,
    )

    for (e, f) in update_functions
        network[e] = f
    end

    for (e1, f) in update_functions
        leaves = get_rule.(collect(Leaves(f)))
        input_variables = grammar.rules[leaves]
        for e2 in input_variables
            add_edge!(network, e1, e2)
        end
    end

    return network
end

function sample_qualitative_network(entities::AbstractVector{Symbol}, max_eq_depth::Int)
    g = build_qn_grammar(entities, default_qn_constants)
    update_fns = Dict([e => rand(RuleNode, g, :Val, max_eq_depth) for e in entities])
    graph = update_functions_to_network(update_fns, g)

    return graph
end

function sample_qualitative_network(size::Int, max_eq_depth::Int)
    entities = [Symbol(e) for e = 1:size]
    sample_qualitative_network(entities, max_eq_depth)
end

struct QualitativeNetwork
    graph::MetaGraph
    state::AbstractVector{Int}
    N::Int

    function QualitativeNetwork(g, s, N)
        if any(s .> N)
            error("All values in state must be <= N (N=$N)")
        else
            return new(g, s, N)
        end
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
    return labels(qn.graph)
end

C(qn::QN) = components(qn)

function target_functions(qn::QN)
    return qn.graph.vertex_properties
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

extract_state(model::QN) = model.state
extract_parameters(model::QN) = model.graph

function reset_model!(model::QN, u, _)
    model.state .= u
end
