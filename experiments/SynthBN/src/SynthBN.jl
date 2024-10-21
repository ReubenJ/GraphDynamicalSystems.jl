module SynthBN

using DrWatson
using HerbGrammar
using GraphDynamicalSystems

include("biodivine_benchmark/parse_aeon.jl")
include("biodivine_benchmark/load_aeon.jl")
include("biodivine_benchmark/fetch_repo.jl")

export AEONParser,
    load_aeon_biodivine,
    fetch_biodivine_benchmark,
    bundle_biodivine_benchmark,
    update_functions_to_network

include("grammars.jl")

export build_cnf_grammar, build_dnf_grammar, count_neighbors_in_expr

include("gather_bn_data.jl")

export gather_bn_data, split_state_space, get_split_state_space

end
