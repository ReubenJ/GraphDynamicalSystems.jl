import MetaGraphsNext as MG
import Graphs
import AbstractTrees as AT
import TermInterface as TI
import DynamicalSystemsBase as DSB
import MLStyle
import SciMLBase

public QualitativeNetwork, QN, interpret

"""
    $(TYPEDEF)

A graph dynamical system with a finite domain. State values of each entity are
limited to change by at most 1 per time step.
"""
struct QualitativeNetwork{N_Entities,Schedule,Graph<:MG.MetaGraph} <:
       GraphDynamicalSystem{N_Entities,Schedule}
    graph::Graph
end

"""
    $(TYPEDEF)

Alias for a [`QualitativeNetwork`](@ref).
"""
const QN = QualitativeNetwork

DSB.isinplace(::QualitativeNetwork) = true
DSB.dynamic_rule(qn::QualitativeNetwork) = get_fn(qn)
DSB.current_parameters(qn::QualitativeNetwork) = ()
DSB.current_time(::QualitativeNetwork) = 0
DSB.reinit!(qn::QN, state::AbstractVector) = DSB.set_state!(qn, Int.(state))


mutable struct QNEntity{F,S,D} <: AbstractEntity
    fn::F
    state::S
    domain::D
end

get_fn(qne::QNEntity) = qne.fn
DSB.current_state(qne::QNEntity) = qne.state
function DSB.set_state!(qne::QNEntity, s)
    domain = get_domain(qne)
    if s < minimum(domain) || s > maximum(domain)
        error(
            "New state value for entity must be within its domain (domain: $domain, new state: $s)",
        )
    end
    qne.state = s
end
get_domain(qne::QNEntity) = qne.domain

function QualitativeNetwork(graph::G) where {G<:Graphs.AbstractGraph}
    QualitativeNetwork{Graphs.nv(graph),Synchronous(),G}(graph)
end

function QualitativeNetwork(update_functions::AbstractDict, domains)
    QualitativeNetwork{Graphs.SimpleDiGraph}(update_functions, domains)
end

"""
    $(TYPEDSIGNATURES)

Create a [`QualitativeNetwork`](@ref) from the dictionary `update_functions` which should map from entities (`E`) to their functions (`F`)

The entity names (`E` in the signature) can be anything, while the functions (`F`) are required to either

- be a numerical constant (like `1`), or a reference to a single entity (like `A`)
- implement the `TermInterface.jl` interface. Any terminal nodes in the functions must be numerical constants or reference an entity.
"""
function QualitativeNetwork{GraphType}(
    update_functions::AbstractDict{E,F},
    domains,
)::QualitativeNetwork where {E,F,GraphType<:Graphs.AbstractGraph}
    entity_keys = collect(keys(update_functions))
    entity_fns = getindex.((update_functions,), entity_keys)
    entity_domains = getindex.((domains,), entity_keys)
    get_arguments_or_empty = x -> TI.isexpr(x) ? (x, TI.arguments(x)) : (x, ())
    collect_arguments =
        x ->
            AT.treemap(get_arguments_or_empty, x) |>
            AT.Leaves .|>
            AT.nodevalue |>
            filter(in(entity_keys))

    referenced_entities = union.(collect_arguments.(entity_fns))
    referenced_indices =
        map(ref_for_e -> findfirst.(.==(ref_for_e), (entity_keys,)), referenced_entities)
    edges =
        Iterators.flatten(
            map(((j, idxs),) -> tuple.(idxs, (j,)), enumerate(referenced_indices)),
        ) |> collect
    graph = GraphType()
    Graphs.add_vertices!(graph, length(entity_keys))
    Graphs.add_edge!.((graph,), Graphs.Edge.(edges))
    vertices_description = Pair{Symbol,QNEntity}[
        (e => QNEntity(fn, 0, d)) for
        (e, fn, d) in zip(entity_keys, entity_fns, entity_domains)
    ]
    edges_description = Pair{Tuple{E,E},Nothing}[
        (entity_keys[s], entity_keys[d]) => nothing for (s, d) in edges
    ]
    return QualitativeNetwork(
        MG.MetaGraph(graph, vertices_description, edges_description, nothing),
    )
end

function SciMLBase.step!(qn::QualitativeNetwork{N,S}) where {N,S}
    SciMLBase.step!(S, qn)
end
SciMLBase.step!(qn::QN, n::Int, _...) = foreach(_ -> SciMLBase.step!(qn), 1:n)

function limit_change(next, prev, lower, upper)
    if next > prev
        min(upper, prev + 1)
    elseif next < prev
        max(lower, prev - 1)
    else
        next
    end
end

function DSB.set_state!(
    qn::QN{N,S,M},
    new_state::Int,
    entity::L,
) where {N,S,I,G,L,M<:MG.MetaGraph{I,G,L}}
    g = get_graph(qn)
    DSB.set_state!(g[entity], new_state)
end

function DSB.set_state!(qn::QN, new_state::AbstractVector)
    g = get_graph(qn)

    DSB.set_state!.((qn,), new_state, MG.labels(g))
end

function SciMLBase.step!(::Synchronous, qn::QualitativeNetwork)
    l = MG.labels(get_graph(qn))
    current_state = DSB.current_state(qn)
    current_state_dict = Dict(l .=> current_state)
    domains = get_domain(qn)
    lower_bounds = minimum.(domains)
    upper_bounds = maximum.(domains)
    fns = get_fn(qn)
    next_state_uncapped = interpret.(fns, (current_state_dict,))
    next_state_capped =
        limit_change.(next_state_uncapped, current_state, lower_bounds, upper_bounds)
    DSB.set_state!(qn, next_state_capped)

    return qn
end

function interpret(fn, state)
    MLStyle.@match fn begin
        ::Int => fn
        ::Symbol => state[fn]
        :($a + $b) => interpret(a, state) + interpret(b, state)
        :($a - $b) => interpret(a, state) - interpret(b, state)
        :($a / $b) => interpret(a, state) / interpret(b, state)
        :(min($a, $b)) => min(interpret(a, state), interpret(b, state))
        :(max($a, $b)) => max(interpret(a, state), interpret(b, state))
        :(ceil($a)) => ceil(interpret(a, state))
        :(floor($a)) => floor(interpret(a, state))
        _ => error("Unhandled expression: $fn")
    end
end
interpret(fn, qn::QN) = interpret(fn, Dict(entities(qn) .=> DSB.current_state(qn)))
