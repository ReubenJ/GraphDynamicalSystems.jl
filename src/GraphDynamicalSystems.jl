module GraphDynamicalSystems

using DocStringExtensions
using DynamicalSystems
using MetaGraphsNext
using SoleLogics


include("boolean_networks.jl")
export BooleanNetworks

include("qualitative_networks.jl")
export QualitativeNetwork,
    build_qn_grammar,
    update_functions_to_network,
    sample_qualitative_network,
    max_level,
    components,
    C,
    get_state,
    S,
    target_functions,
    T,
    set_state!,
    interpret,
    aqn

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
