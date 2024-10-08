function evaluate_bn(problem, expr)
    sat_examples = 0

    for example ∈ problem.spec
        truth = TruthDict(Dict(enumerate(example.in[:state])))
        res = interpret(eval(expr), truth)
        sat_examples += res.flag == example.out
    end

    return sat_examples / length(problem.spec)
end
