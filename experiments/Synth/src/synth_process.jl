function synth_biodivine(
    problem,
    iterator,
    grammar,
    max_iterations,
    evaluator,
    vertex_names,
)
    exprs_and_scores = []

    for (i, ex) in enumerate(iterator)
        if i % 100000 == 0
            @info "$i iterations, problem $(problem.name)"
        end

        expr = rulenode2expr(ex, grammar)

        sat_examples = evaluator(problem, expr, vertex_names)

        # if all examples worked in at least one direction
        if sum(all.(==(false), sat_examples)) == 0
            score = sum(count.(sat_examples)) / (2 * length(problem.examples))
            push!(exprs_and_scores, (expr, score, sat_examples, i))
        end

        if i > max_iterations
            @warn "Maximum iterations reached"
            break
        end
    end

    return exprs_and_scores
end
