import DynamicalSystemsBase.get_state
using MetaGraphsNext: labels

abstract type ScheduleStyle end
struct Asynchronous <: ScheduleStyle end
struct Synchronous <: ScheduleStyle end

abstract type GraphDynamicalSystem{N,S} end
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

"""
    $(TYPEDSIGNATURES)

Get the state of the GDS.
"""
function get_state(gds::GDS)
    return gds.state
end
