using DrWatson

@quickactivate :SynthBN

using DataFrames
using GraphDynamicalSystems: BooleanNetworks
using Term: Progress, ProgressBar
using MetaGraphsNext

mg_df = collect_results!(datadir("src_parsed", "biodivine_benchmark_as_metagraphs"))
mg_df[!, :ID] = ((x -> x[1]) ∘ splitext ∘ basename).(mg_df.path)
mg_df_by_id = groupby(mg_df, :ID)

param_setup = Dict("id" => mg_df.ID, "n_trajectories" => 1000, "iterations" => 1000)
all_params = dict_list(param_setup)

pbar = ProgressBar(; columns = :detailed)
Progress.foreachprogress(
    all_params,
    pbar;
    parallel = true,
    # description = "Collecting trajectories",
) do params
    @produce_or_load(params, path = datadir("sims", "biodivine_trajectories"),) do params
        @unpack id, n_trajectories, iterations = params
        bn = mg_df_by_id[(id,)].metagraph_model[1]
        trajectories = []
        for traj_i = 1:n_trajectories
            async_bn = BooleanNetworks.abn(bn; seed = traj_i)
            push!(trajectories, gather_bn_data(async_bn, iterations))
        end
        @strdict trajectories
    end
end
