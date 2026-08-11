module Schedule
using Compat: @compat
using ..Interface: vertices, schedule_style

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
`to_update(::MySchedule, gds)` and `determinism(::MySchedule)`.
"""
abstract type ScheduleStyle end

"""
    Determinism

Trait defining the determinism of a schedule style.
"""
abstract type Determinism end
struct Deterministic <: Determinism end
struct NonDeterministic <: Determinism end

"""
    is_deterministic(gds)

Whether the `gds` has a deterministic schedule.
"""
function is_deterministic(gds)
    return is_deterministic(schedule_style(gds))
end

"""
    is_deterministic(s::ScheduleStyle)

Whether schedule `s` is deterministic.
"""
function is_deterministic(s::ScheduleStyle)
    return is_deterministic(determinism(s))
end

function is_deterministic(::Deterministic)
    return true
end

function is_deterministic(::NonDeterministic)
    return false
end

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
    return rand(collect(vertices(gds)), 1)
end

function determinism(::Asynchronous)
    return NonDeterministic()
end

"""
    Synchronous

A synchronous schedule updates _all_ vertices at each timestep.
"""
struct Synchronous <: ScheduleStyle end

function to_update(::Synchronous, gds)
    return vertices(gds)
end

function determinism(::Synchronous)
    return Deterministic()
end

end
