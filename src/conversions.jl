module Conversions
using Compat: @compat

@compat public to_simple_graph, to_arbitrary_steppable

"""
    to_simple_graph(gds)

Convert `gds` to a [`Graphs.SimpleDiGraph`](https://juliagraphs.org/Graphs.jl/dev/core_functions/simplegraphs/#Graphs.SimpleGraphs.SimpleDiGraph).

`gds` is required to implement the GDS interface.

!!! tip
    Use this method when an object `<:AbstractGraph` is necessary.
    The `Graphs` ecosystem currently requires this for most (all?)
    of its functionality. Until a trait-based version of the ecosystem
    arrives, then one must use this method (or one like it) to construct
    something that is `<:AbstractGraph`.

!!! note
    Requires `Graphs` to be loaded.
"""
function to_simple_graph end # implemented in ext/GraphsExt.jl

"""
    to_arbitrary_steppable(gds)

Convert `gds` to a [`DynamicalSystemsBase.ArbitrarySteppable`](https://juliadynamics.github.io/DynamicalSystemsDocs.jl/dynamicalsystemsbase/stable/#ArbitrarySteppable).

`gds` is required to implement the GDS interface.

!!! tip
    Use this method when an object `<:DynamicalSystem` is necessary.
    The `DynamicalSystems` ecosystem currently requires this for most (all?)
    of its functionality. Until a trait-based version of the ecosystem
    arrives, then one must use this method (or one like it) to construct
    something that is `<:DynamicalSystem`.

!!! note
    Requires `DynamicalSystemsBase` to be loaded.
"""
function to_arbitrary_steppable end # implemented in ext/DynamicalSystemBase.jl


"""
    to_discrete_system(gds)

Convert `gds` to a [`AlgebraicDynamics.DWDDynam.DiscreteMachine`](https://algebraicjulia.github.io/AlgebraicDynamics.jl/dev/api/#AlgebraicDynamics.DWDDynam.DiscreteMachine).

`gds` is required to implement the GDS interface.

!!! note
    Currently unimplemented as a number of dependencies within the
    `AlgebraicJulia` ecosystem are not up to date and conflict with those of other
    extensions.
"""
function to_discrete_system end

end
