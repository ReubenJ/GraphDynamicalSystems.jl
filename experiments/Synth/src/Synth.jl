module Synth

using DrWatson
using HerbGrammar
using GraphDynamicalSystems
using HerbSpecification

include("parse_aeon.jl")

export AEONParser

include("biodivine_benchmark.jl")

export load_aeon_biodivine,
    get_biodivine_repo,
    bundle_biodivine_benchmark,
    update_functions_to_network,
    convert_aeon_models_to_metagraphs,
    synth_one_biodivine,
    synth_one_vertex

include("grammars.jl")

export build_cnf_grammar, build_dnf_grammar, count_neighbors_in_expr

include("gather_bn_data.jl")

export gather_bn_data, split_state_space, get_split_state_space

include("create_problem.jl")

export examples_to_problem

include("evaluator.jl")

export evaluate_bn, interpret

include("synth_process.jl")

export synth, synth_biodivine

end
