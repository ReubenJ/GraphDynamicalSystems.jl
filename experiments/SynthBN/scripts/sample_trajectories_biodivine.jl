using DrWatson

@quickactivate :SynthBN

using DataFrames
using GraphDynamicalSystems: BooleanNetworks

mg_df = collect_results!(datadir("src_parsed", "biodivine_benchmark_as_metagraphs"))

param_setup = Dict(
    "bn" => mg_df.metagraph_model,
    "id" => ((x -> x[1]) ∘ splitext ∘ basename).(mg_df.path),
    "n_trajectories" => 1000,
    "iterations" => 1000,
)
all_params = dict_list(param_setup)

for params in all_params
    @produce_or_load(params, datadir("sims", "biodivine_trajectories"),) do params
        @unpack bn, n_trajectories, iterations = params
        for traj_i = 1:n_trajectories
            async_bn = BooleanNetworks.abn(bn; seed = traj_i)
            gather_bn_data(async_bn, iterations)
        end
    end
end
