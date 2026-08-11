module DynamicalSystemsBaseExt
import DynamicalSystemsBase as DSB
import GraphDynamicalSystems as GDS

function step!(gds)
    v_to_update = GDS.to_update(gds)
    current_state = Dict(GDS.vertices(gds) .=> GDS.get_state(gds))
    new_state = v_to_update .=> [f(current_state) for f in GDS.update_function(gds, v_to_update)]
    GDS.set_state!(gds, new_state)
    return nothing
end

function extract_state(gds)
    return GDS.get_state(gds)
end

function extract_parameters(::Any)
    return () # no parameters exposed by default
end

function reset_model!(gds, u, ::Any)
    GDS.set_state!(gds, round.(Int, u))
    return nothing
end

function GDS.Conversions.to_arbitrary_steppable(gds)
    isdeterministic = GDS.is_deterministic(gds)

    return DSB.ArbitrarySteppable(
        gds,
        step!,
        extract_state,
        extract_parameters,
        reset_model!;
        isdeterministic
    )
end

function DSB.reinit!(as::DSB.ArbitrarySteppable, u)
    as.reinit(as.model, u, ())
    return nothing
end

# Implements part of the GDS interface for DSB's `DynamicalSystem`s
# Useful to apply methods written over the GDS interface directly to
# some DSB-based object.
GDS.update_function(ds::DSB.DynamicalSystem) = DSB.dynamic_rule(ds)
GDS.get_state(ds::DSB.DynamicalSystem) = DSB.current_state(ds)
GDS.set_state!(ds::DSB.DynamicalSystem, u::AbstractVector{<:Real}) = DSB.set_state!(ds, u)
end
