module Schedule
using Compat: @compat
using ..Interface: vertices

@compat public ScheduleStyle,
    Asynchronous,
    Synchronous

"""
    ScheduleStyle

Trait defining the schedule of a GDS.

A schedule defines which vertices are updated and in which order.
Two basic common schedule types are [`Asynchronous`](@ref) and
[`Synchronous`](@ref).

A new schedule type `MySchedule<:ScheduleStyle` should implement
`to_update(::MySchedule, gds)`.
"""
abstract type ScheduleStyle end

"""
    to_update(gds)

Get the vertices of the `gds` to update at the current timestep.

Implement `to_update(::ScheduleStyle, gds)` for new schedule types.
"""
function to_update(gds)
    return to_update(schedule_style(gds), gds)
end

"""
    Asynchronous

An asynchronous schedule randomly chooses a vertex to update at each timestep.
"""
struct Asynchronous <: ScheduleStyle end

function to_update(::Asynchronous, gds)
    return rand(vertices(gds), 1)
end

"""
    Synchronous

A synchronous schedule updates _all_ vertices at each timestep.
"""
struct Synchronous <: ScheduleStyle end

function to_update(::Synchronous, gds)
    return vertices(gds)
end
end
