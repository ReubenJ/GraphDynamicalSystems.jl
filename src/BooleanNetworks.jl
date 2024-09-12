module BooleanNetworks

using MetaGraphsNext: MetaGraph, add_edge!, SimpleDiGraph
using SoleLogics:
    Formula, Atom, ExplicitAlphabet, randformula, normalize, subformulas, ∧, ∨, ¬

"""
    sample_boolean_network(n::Int)

Return a random Boolean network with `n` nodes.
"""
function sample_boolean_network(n::Int, depth::Int = 2, seed::Int = 0)
    # Create a SoleLogics Atom for each node
    alphabet = ExplicitAlphabet([Atom("x$i") for i = 1:n])
    operators = [∧, ∨, ¬]
    formulas =
        [normalize(randformula(depth, alphabet, operators; rng = seed + i)) for i = 1:n]

    # Create a meta graph
    bn = MetaGraph(SimpleDiGraph(); label_type = Int, vertex_data_type = Formula)

    for i = 1:n
        bn[i] = formulas[i]
    end

    # Add edges to the graph based on the formulas
    for i = 1:n
        atoms = filter(x -> isa(x, Atom), subformulas(formulas[i]))
        for atom in atoms
            j = parse(Int, split(atom.value, "x")[2])
            add_edge!(bn, i, j)
        end
    end

    return bn
end

end
