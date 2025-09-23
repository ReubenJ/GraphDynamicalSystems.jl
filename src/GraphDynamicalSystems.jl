module GraphDynamicalSystems

using DocStringExtensions

include("gds_interface.jl")
export ScheduleStyle, Asynchronous, Synchronous, get_schedule, get_state, get_graph

include("qualitative_networks.jl")
export QualitativeNetwork,
    QN,
    build_qn_grammar,
    update_functions_to_interaction_graph,
    sample_qualitative_network,
    entities,
    get_domain,
    target_functions,
    interpret,
    create_qn_system

end
