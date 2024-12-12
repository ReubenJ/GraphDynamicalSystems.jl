function examples_to_problem(node, examples)
    io_examples =
        map(((in, out),) -> IOExample(Dict([:state => in]), out), collect(examples))
    problem = Problem("$node", io_examples)

    return problem
end
