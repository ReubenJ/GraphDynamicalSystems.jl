@testset "State division" begin
    network_size = 10
    max_equation_depth = 3
    seed = 42
    iterations = 1000

    bn = BooleanNetworks.sample_boolean_network(network_size, max_equation_depth, seed)
    async_bn = BooleanNetworks.abn(bn; seed = seed)
    trajectory = gather_bn_data(async_bn, iterations)
    divided_state_space = split_state_space(trajectory)
end
