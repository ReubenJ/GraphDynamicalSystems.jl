module GraphDynamicalSystems

using SoleLogics
using MetaGraphsNext
using DynamicalSystems

include("boolean_networks.jl")
export BooleanNetworks

include("qualitative_networks.jl")
export QualitativeNetworks

# """
#     gds(bn::MetaGraph)

# Creates a [graph dynamical system](https://en.wikipedia.org/wiki/Graph_dynamical_system).
# The structure of the system is defined by the given `graph`, the initial state by the `state` vector,
# the vertex functions by the `vertex_functions` dictionary, and the update scheme by the `update_scheme`

# """
# function gds(graph::SimpleDiGraph, state, vertex_functions, update_scheme)
#     return ArbitrarySteppable(
#         model,
#         step!,
#     )

# end

end
