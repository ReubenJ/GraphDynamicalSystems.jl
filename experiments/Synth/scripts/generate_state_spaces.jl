using DrWatson

@quickactivate :Synth

using DataFrames
using HerbGrammar, SoleLogics, HerbSpecification, HerbSearch

include(srcdir("gather_bn_data.jl"))
include(srcdir("grammars.jl"))

param_setup = Dict(
    "network_size" => 10,
    "max_equation_depth" => 3,
    "iterations" => 1000,
    "repetitions" => 10,
    "seed" => collect(0:9),
)
all_params = dict_list(param_setup)

for params in all_params
    @produce_or_load(get_split_state_space, params, datadir("sims", "specs"))
end
