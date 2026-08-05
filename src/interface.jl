module Interface
using Compat: @compat

@compat public schedule_style,
    domain,
    update_function,
    get_state,
    set_state!,
    vertices,
    edges

"""
    schedule_style(gds)

Get the schedule style of the `gds`.

Also referred to as the update scheme.
"""
function schedule_style end

"""
    update_function(gds)
    update_function(gds, vertices...)

Get the update function of (all/some) `vertices` of the `gds`.

Also referred to as "vertex function(s)".
"""
function update_function end

"""
    domain(gds)
    domain(gds, vertices...)

Get the domain of (all/some) `vertices` of the `gds`.
"""
function domain end

"""
    get_state(gds)
    get_state(gds, vertices...)

Get the state of the `gds`.
"""
function get_state end

"""
    set_state!(gds, new_state)
    set_state!(gds, vertex_state_pairs...)

Set the state of the `gds`.

Set the state of specific vertices by supplying pairs of vertices and states.
"""
function set_state! end

"""
    vertices(gds)

Get the vertices of the `gds`.
"""
function vertices end

"""
    edges(gds)

Get the edges of the `gds`.
"""
function edges end

end
