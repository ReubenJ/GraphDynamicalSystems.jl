module GraphDynamicalSystems

using Compat: @compat
using DocStringExtensions: TYPEDSIGNATURES

include("interface.jl")

using .Interface: schedule_style, domain, update_function, get_state,
    set_state!, vertices, edges

@compat public schedule_style,
    domain,
    update_function,
    get_state,
    set_state!,
    vertices,
    edges

include("schedule.jl")

using .Schedule: ScheduleStyle, Asynchronous, Synchronous, to_update

@compat public ScheduleStyle, Asynchronous, Synchronous, to_update

end
