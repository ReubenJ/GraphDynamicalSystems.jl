import DynamicalSystemsBase as DSB
import MetaGraphsNext: labels
import Compat: @compat

@compat begin
public ScheduleStyle,
    Asynchronous,
    Synchronous,
    GraphDynamicalSystem,
    GDS,
    get_n_entities,
    get_schedule,
    get_graph,
    get_domain,
    get_fn
end

abstract type ScheduleStyle end
struct Asynchronous <: ScheduleStyle end
struct Synchronous <: ScheduleStyle end

# A GDS is a DiscreteTimeDynamicalSystem where the model is a MetaGraph with
# functions at each of the vertices in the graph. The parameters of the system
# include the ranges of each of the entities. The state of the system is just
# the current value of each of the entities

abstract type GraphDynamicalSystem{N,S} <: DSB.DiscreteTimeDynamicalSystem end
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

"""
    $(TYPEDSIGNATURES)

Get the state of the GDS.
"""
function DSB.current_state(gds::GDS)
    g = get_graph(gds)
    l = labels(g)
    return DSB.current_state.(getindex.((g,), l))
end

function DSB.current_state(gds::GDS, entity)
    g = get_graph(gds)
    return DSB.current_state(g[entity])
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
