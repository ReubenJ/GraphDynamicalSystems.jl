module BooleanNetworks
import AbstractTrees as AT
import GraphDynamicalSystems as GDS
import MetaGraphsNext as MG
using Graphs: Graphs
using Compat: @compat

@compat public BooleanNetwork

mutable struct VertexData
    update_function::Any
    state::Bool
end
GDS.update_function(e::VertexData) = e.update_function
GDS.get_state(e::VertexData) = e.state
function GDS.set_state!(e::VertexData, v::Integer)
    return e.state = v
end
GDS.domain(e::VertexData) = false:true

const BNGraphType{G <: Graphs.AbstractGraph{Int}, L, V <: VertexData} = MG.MetaGraph{Int, G, L, V}

"""
    BooleanNetwork

A graph dynamical system with Boolean domains.

Update functions are Boolean functions. The schedule style is `Asynchronous` by
default, but can be specified by passing a different type to the first type
parameter explicitly.

Alias: [`BN`](@ref).
"""
struct BooleanNetwork{S <: GDS.ScheduleStyle, G <: BNGraphType}
    graph::G
end

"""
    BN

Alias for a [`BooleanNetwork`](@ref).
"""
const BN = BooleanNetwork

function BooleanNetwork{S}(vs, fns) where {S}
    edge_list = GDS.Constructors.vertex_function_to_edgelist(vs .=> fns)
    e = [Graphs.Edge(findfirst(==(s), vs), findfirst(==(d), vs)) for (s, d) in edge_list]
    simple_graph = Graphs.SimpleDiGraph(e)
    vertex_data = vs .=> VertexData.(fns, falses(length(vs)))
    edge_data = Tuple.(edge_list) .=> nothing # could add edge sign here
    meta_graph = MG.MetaGraph(simple_graph, vertex_data, edge_data)

    return BooleanNetwork{S, typeof(meta_graph)}(meta_graph)
end

function GDS.schedule_style(::BooleanNetwork{S}) where {S}
    return S()
end

function GDS.domain(bn::BN, vertices = MG.labels(bn.graph))
    return GDS.domain.(getindex.((bn.graph,), vertices))
end

function GDS.update_function(bn::BN, vertices = MG.labels(bn.graph))
    return GDS.update_function.(getindex.((bn.graph,), vertices))
end

function GDS.get_state(bn::BN, vertices = MG.labels(bn.graph))
    return GDS.get_state.(getindex.((bn.graph,), vertices))
end

function GDS.set_state!(bn::BN, state::AbstractVector{<:Integer})
    g = bn.graph
    return foreach(((i, v),) -> GDS.set_state!(g[v], state[i]), enumerate(MG.labels(g)))
end

function GDS.set_state!(bn::BN, vertex_state_pairs::AbstractVector{<:Pair})
    g = bn.graph
    return foreach(((v, s),) -> GDS.set_state!(g[v], s), vertex_state_pairs)
end

function GDS.vertices(bn::BN)
    return MG.labels(bn.graph)
end

function GDS.edges(bn::BN)
    return MG.edge_labels(bn.graph)
end

end
