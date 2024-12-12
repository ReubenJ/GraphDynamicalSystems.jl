module GraphDynamicalSystems

using DocStringExtensions
using DynamicalSystems
using MetaGraphsNext
using SoleLogics


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

include("io/bma.jl")
export load_bma_file, bma_vars_to_grammar_style

end
