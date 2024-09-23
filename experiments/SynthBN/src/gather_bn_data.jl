using GraphDynamicalSystems.BooleanNetworks: sample_boolean_network, abn
using DynamicalSystems: trajectory, ArbitrarySteppable, length, StateSpaceSet

function gather_bn_data(bn::ArbitrarySteppable, iterations::Int)
    return trajectory(bn, iterations)[1]
end

function split_state_space(trajectory::StateSpaceSet)
    # split into pairs of input (all values) and output (changed value)
    input_output_pairs_per_node = Dict{Int,Set{Tuple{Vector{Int},Int}}}()
    for i = 1:length(trajectory)-1
        changed = findfirst(trajectory[i+1] .!= trajectory[i])
        # only proceed if there was a change
        if !isnothing(changed)
            new_value = trajectory[i+1][changed]
            existing_pairs = get(input_output_pairs_per_node, changed, Set())
            push!(existing_pairs, (trajectory[i], new_value))
            input_output_pairs_per_node[changed] = existing_pairs
        end
    end

    return input_output_pairs_per_node
end

function get_split_state_space(
    network_size::Int,
    max_equation_depth::Int,
    iterations::Int,
    seed::Int,
)
    bn = sample_boolean_network(network_size, max_equation_depth, seed)
    async_bn = abn(bn; seed = seed)
    trajectory = gather_bn_data(async_bn, iterations)
    return split_state_space(trajectory), bn, async_bn, trajectory
end

function get_split_state_space(params::Dict{String,<:Any})
    @unpack network_size, max_equation_depth, iterations, repetitions, seed = params

    fulld::Dict{String,Any} = copy(params)

    all_divided_state_space = Dict{Int,Set{Tuple{Vector{Int},Int}}}()
    all_abns = Dict{Int,Any}()

    bn = sample_boolean_network(network_size, max_equation_depth, seed)
    for r = 1:repetitions
        async_bn = abn(bn; seed = seed * r)
        trajectory = gather_bn_data(async_bn, iterations)
        divided_state_space = split_state_space(trajectory)
        for (node, pairs) in divided_state_space
            existing_pairs = get(all_divided_state_space, node, Set())
            push!(existing_pairs, pairs...)
            all_divided_state_space[node] = existing_pairs
        end
        all_abns[r] = async_bn
    end

    fulld["specifications"] = all_divided_state_space
    fulld["bn"] = bn
    fulld["abns"] = all_abns

    return fulld
end
