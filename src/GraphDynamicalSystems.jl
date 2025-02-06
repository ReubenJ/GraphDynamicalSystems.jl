module GraphDynamicalSystems

using DocStringExtensions


include("boolean_networks.jl")
export BooleanNetworks

include("qualitative_networks.jl")
export QualitativeNetwork,
    QN,
    build_qn_grammar,
    update_functions_to_network,
    sample_qualitative_network,
    max_level,
    components,
    target_functions,
    interpret,
    aqn

end
