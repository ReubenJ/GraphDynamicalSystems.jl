import MetaGraphsNext as MG
import Graphs
import AbstractTrees as AT
import TermInterface as TI
import DynamicalSystemsBase as DSB
import MLStyle
import SciMLBase

struct QualitativeNetwork{N_Entities,Schedule,Graph<:MG.MetaGraph} <:
       GraphDynamicalSystem{N_Entities,Schedule}
    graph::Graph
end

DSB.isinplace(::QualitativeNetwork) = true
DSB.dynamic_rule(qn::QualitativeNetwork) = identity
DSB.current_parameters(qn::QualitativeNetwork) = ()
DSB.current_time(::QualitativeNetwork) = 0
DSB.current_state(::QualitativeNetwork{N}) where {N} = zeros(N)


mutable struct QNEntity{F,S,D} <: AbstractEntity
    fn::F
    state::S
    domain::D
end

get_fn(qne::QNEntity) = qne.fn
get_state(qne::QNEntity) = qne.state
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
- implement the `TermInterface.jl` interface. Any terminal nodes in the functionsmust be numerical constants or reference an entity.
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
    graph = GraphType(Graphs.Edge.(edges))
    vertices_description = Pair{Symbol,QNEntity}[
        (e => QNEntity(fn, 0, d)) for
        (e, fn, d) in zip(entity_keys, entity_fns, entity_domains)
    ]
    edges_description =
        Pair.([(entity_keys[s], entity_keys[d]) for (s, d) in edges], nothing)
    return QualitativeNetwork(
        MG.MetaGraph(graph, vertices_description, edges_description, nothing),
    )
end

function SciMLBase.step!(qn::QualitativeNetwork{N,S}) where {N,S}
    SciMLBase.step!(S, qn)
end

function limit_change(next, prev, lower, upper)
    if next > prev
        min(upper, prev + 1)
    elseif next < prev
        max(lower, prev - 1)
    else
        next
    end
end

function set_state!(qn, new_state)
    g = get_graph(qn)
    l = MG.labels(g)
    entities = getindex.((g,), l)

    for (x, state) in zip(entities, new_state)
        x.state = state
    end
end

function SciMLBase.step!(::Synchronous, qn::QualitativeNetwork)
    l = MG.labels(get_graph(qn))
    current_state = get_state(qn)
    current_state_dict = Dict(l .=> current_state)
    domains = get_domain(qn)
    lower_bounds = minimum.(domains)
    upper_bounds = maximum.(domains)
    fns = get_fn(qn)
    next_state_uncapped = interpret.(fns, (current_state_dict,))
    next_state_capped =
        limit_change.(next_state_uncapped, current_state, lower_bounds, upper_bounds)
    set_state!(qn, next_state_capped)
end

function interpret(fn, state)
    MLStyle.@match fn begin
        ::Int => fn
        ::Symbol => state[fn]
        :($a + $b) => interpret(a, state) + interpret(b, state)
        :($a - $b) => interpret(a, state) - interpret(b, state)
        _ => error(fn)
    end
end
