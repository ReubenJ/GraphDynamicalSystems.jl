function _e2p(n, e)
    _pair_to_undirected(p) = UndirectedExample(Dict(:state => p[1]), Dict(:state => p[2]))

    return UndirectedProblem(n, _pair_to_undirected.(e))
end

examples_to_problem(node::Integer, examples::AbstractSet) = _e2p(string(node), examples)
examples_to_problem(node::Atom, examples) = _e2p(node.value, examples)
examples_to_problem(node::AbstractString, examples) = _e2p(node, examples)
