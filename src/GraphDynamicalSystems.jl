module GraphDynamicalSystems

using Compat: @compat

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

using .Schedule: ScheduleStyle, Asynchronous, Synchronous, to_update, determinism, is_deterministic

@compat public ScheduleStyle, Asynchronous, Synchronous, to_update, determinism, is_deterministic

include("conversions.jl")

using .Conversions: Conversions, to_simple_graph, to_arbitrary_steppable

@compat public Conversions, to_simple_graph, to_arbitrary_steppable

include("constructors.jl")

using .Constructors: Constructors, vertex_function_to_edgelist

@compat public Constructors, vertex_function_to_edgelist

end
