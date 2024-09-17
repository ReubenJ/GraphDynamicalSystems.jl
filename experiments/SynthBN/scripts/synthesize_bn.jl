using DrWatson

@quickactivate "SynthBN"

include(srcdir("gather_bn_data.jl"))

all_params = Dict(
    "network_size" => 10,
    "max_equation_depth" => 3,
    "iterations" => 1000,
    "seed" => collect(0:9),
)
dicts = dict_list(all_params)

@show dicts

for (i, d) in enumerate(dicts)
    data, file = @produce_or_load(get_split_state_space, d, datadir("sims", "specs"))
    @show data, file
end
