module GraphDynamicalSystems

using DocStringExtensions

include("gds_interface.jl")
export GraphDynamicalSystem,
    GDS,
    ScheduleStyle,
    Asynchronous,
    Synchronous,
    get_n_entities,
    entities,
    get_schedule,
    get_state,
    get_graph

include("qualitative_networks.jl")
export QualitativeNetwork,
    QN,
    Entity,
    build_qn_grammar,
    update_functions_to_interaction_graph,
    sample_qualitative_network,
    get_domain,
    target_functions,
    interpret,
    create_qn_system,
    default_target_function

end
