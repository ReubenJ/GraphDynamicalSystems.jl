module BooleanNetworks

using MetaGraphsNext: MetaGraph, add_edge!, SimpleDiGraph, nv, labels
using DynamicalSystems: ArbitrarySteppable
using SoleLogics:
    Formula,
    Atom,
    ExplicitAlphabet,
    randformula,
    normalize,
    subformulas,
    ∧,
    ∨,
    ¬,
    interpret,
    TruthDict,
    BooleanTruth,
    ⊤
using Random: seed!
using FileIO: load

"""
    sample_boolean_network(n::Int)

Return a random Boolean network with `n` nodes.
"""
function sample_boolean_network(n::Int, depth::Int = 2, seed::Int = 0; tactic = normalize)
    # Create a SoleLogics Atom for each node
    alphabet = ExplicitAlphabet(Atom.(1:n))
    operators = [∧, ∨, ¬]
    formulas = [tactic(randformula(depth, alphabet, operators; rng = seed + i)) for i = 1:n]

    bn = update_functions_to_network(formulas)

    return bn
end

function update_functions_to_network(update_functions::AbstractVector{<:Formula})
    network = MetaGraph(SimpleDiGraph(); label_type = Int, vertex_data_type = Formula)

    for (i, f) in enumerate(update_functions)
        network[i] = f
    end

    for (i, f) in enumerate(update_functions)
        atoms = filter(x -> isa(x, Atom), subformulas(f))
        for atom in atoms
            j = atom.value
            add_edge!(network, i, j)
        end
    end

    return network
end

mutable struct BooleanNetwork
    graph::MetaGraph
    state::AbstractVector{Int}
end

function truth_dict_from_state(state::AbstractVector{Int}, labels::AbstractVector)
    return TruthDict(Dict(l => s for (l, s) in zip(labels, state)))
end

function abn_step!(model::BooleanNetwork)
    vertex_labels = collect(labels(model.graph))
    i = rand(vertex_labels)
    fᵢ = model.graph[i]
    td = truth_dict_from_state(model.state, vertex_labels)
    u₍ᵢ₊₁₎ = interpret(fᵢ, td)
    state_index = findfirst(isequal(i), vertex_labels)
    model.state[state_index] = Int(u₍ᵢ₊₁₎.flag)
end

extract_state(model::BooleanNetwork) = model.state
extract_parameters(model::BooleanNetwork) = model.graph

function reset_model!(model::BooleanNetwork, u, _)
    model.state .= u
end

"""
    abn(network, initial_state)

Create an asynchronous Boolean network (ABN) with the given `network`,
`initial_state`. The update scheme for an asynchronous Boolean network
is to choose a random node and update its state, one node at a time.
The random choice is uniform over all nodes.
"""
function abn(network::MetaGraph, initial_state::AbstractVector{Int})
    model = BooleanNetwork(network, initial_state)

    return ArbitrarySteppable(
        model,
        abn_step!,
        extract_state,
        extract_parameters,
        reset_model!,
        isdeterministic = false,
    )
end

function abn(network::MetaGraph; seed::Int = 42)
    n = nv(network)
    seed!(seed)
    initial_state = rand(0:1, n)
    return abn(network, initial_state)
end


end
