import DynamicalSystemsBase: DiscreteTimeDynamicalSystem
import DynamicalSystemsBase as DSB
using MetaGraphsNext: labels

abstract type ScheduleStyle end
struct Asynchronous <: ScheduleStyle end
struct Synchronous <: ScheduleStyle end

# A GDS is a DiscreteTimeDynamicalSystem where the model is a MetaGraph with
# functions at each of the vertices in the graph. The parameters of the system
# include the ranges of each of the entities. The state of the system is just
# the current value of each of the entities

abstract type GraphDynamicalSystem{N,S} <: DiscreteTimeDynamicalSystem end
const GDS = GraphDynamicalSystem

"""
    $(TYPEDSIGNATURES)

Get the number of entities `N` in the GDS.
"""
function get_n_entities(::GDS{N,S}) where {N,S}
    return N
end

"""
    $(TYPEDSIGNATURES)

Get the schedule for the GDS.
"""
function get_schedule(::GDS{N,S}) where {N,S}
    return S
end

"""
    $(TYPEDSIGNATURES)

Get the underlying graph of the GDS.
"""
function get_graph(gds::GDS)
    return gds.graph
end

"""
    $(TYPEDSIGNATURES)

List all entities in `gds`.
"""
function entities(gds::GDS)
    return collect(labels(get_graph(gds)))
end

abstract type AbstractEntity end

function get_fn end
function get_state end

"""
    $(TYPEDSIGNATURES)

Get the state of the GDS.
"""
function get_state(gds::GDS)
    g = get_graph(gds)
    l = labels(g)
    return get_state.(getindex.((g,), l))
end

function get_fn(gds::GDS)
    g = get_graph(gds)
    l = labels(g)
    return get_fn.(getindex.((g,), l))
end

function get_domain(gds::GDS)
    g = get_graph(gds)
    l = labels(g)
    return get_domain.(getindex.((g,), l))
end
