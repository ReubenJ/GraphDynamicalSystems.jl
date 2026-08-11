module QualitativeNetworks
import AbstractTrees as AT # to allow for constructing from symbolic expressions
import GraphDynamicalSystems as GDS
import MetaGraphsNext as MG
using Graphs: Graphs

"""
    VertexData{F, S, D}

Per-vertex data of a [`QN`](@ref).
"""
mutable struct VertexData{S, D}
    update_function::Any
    state::S
    domain::D
end
GDS.update_function(e::VertexData) = e.update_function
GDS.get_state(e::VertexData) = e.state
function GDS.set_state!(e::VertexData, v::Integer)
    return e.state = v
end
GDS.domain(e::VertexData) = e.domain

const QNGraphType{G <: Graphs.AbstractGraph{Int}, L, V <: VertexData} = MG.MetaGraph{Int, G, L, V}

"""
    QualitativeNetwork

A graph dynamical system with a domains of finite integer ranges.

Update functions are functions over the reals but all are truncated to the
domain and rounded to an integer value.
State values of each entity are limited to change by at most 1 per time step.
In some literature, QNs are referred to as "unitary" networks due to this
restriction.

Alias: [`QN`](@ref).
"""
struct QualitativeNetwork{G <: QNGraphType}
    graph::G
end

"""
    QN

Alias for a [`QualitativeNetwork`](@ref).
"""
const QN = QualitativeNetwork

"""
    QualitativeNetwork(vs, fns, ds)

Construct a [`QualitativeNetwork`](@ref) with the vertices `vs`, a _symbolic_
set of functions `fns`, and domains `ds`.

This constructor constructs the graph structure based on the functions `fns`.
It does so by adding an edge from `src` to `dst` whenever the function for `dst`
mentioned `src`.

The `fns` must implement the [`AbstractTrees`](https://juliacollections.github.io/AbstractTrees.jl/stable/) interface.
"""
function QualitativeNetwork(vs, fns, ds)
    edge_list = GDS.Constructors.vertex_function_to_edgelist(vs .=> fns)
    e = [Graphs.Edge(findfirst(==(s), vs), findfirst(==(d), vs)) for (s, d) in edge_list]
    simple_graph = Graphs.SimpleDiGraph(e)
    vertex_data = vs .=> VertexData.(fns, zeros(length(vs)), ds)
    edge_data = Tuple.(edge_list) .=> nothing # could add edge sign here
    meta_graph = MG.MetaGraph(simple_graph, vertex_data, edge_data)

    return QualitativeNetwork(meta_graph)
end

function GDS.schedule_style(qn::QN)
    return GDS.Synchronous()
end

function GDS.domain(qn::QN, vertices = MG.labels(qn.graph))
    return GDS.domain.(getindex.((qn.graph,), vertices))
end

function GDS.update_function(qn::QN, vertices = MG.labels(qn.graph))
    return GDS.update_function.(getindex.((qn.graph,), vertices))
end

function GDS.get_state(qn::QN, vertices = MG.labels(qn.graph))
    return GDS.get_state.(getindex.((qn.graph,), vertices))
end

function GDS.set_state!(qn::QN, state::AbstractVector{<:Integer})
    g = qn.graph
    return foreach(((i, v),) -> GDS.set_state!(g[v], state[i]), enumerate(MG.labels(g)))
end

function GDS.set_state!(qn::QN, vertex_state_pairs::AbstractVector{<:Pair})
    g = qn.graph
    return foreach(((v, s),) -> GDS.set_state!(g[v], s), vertex_state_pairs)
end

function GDS.vertices(qn::QN)
    return MG.labels(qn.graph)
end

function GDS.edges(qn::QN)
    return MG.edge_labels(qn.graph)
end

end
