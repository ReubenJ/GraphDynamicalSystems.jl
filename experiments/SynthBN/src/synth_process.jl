function synth(problem, iterator, grammar, max_neighbors, max_iterations)
    exprs_and_scores = []

    for (i, ex) in enumerate(iterator)
        if count_neighbors_in_expr(ex, grammar) > max_neighbors
            @info "Explored up to $max_neighbors neighbors"
            break
        end

        expr = rulenode2expr(ex, grammar)

        score = evaluate_bn(problem, expr)

        push!(exprs_and_scores, (eval(expr), score))

        if i > max_iterations
            @warn "Maximum iterations reached"
            break
        end
    end

    return exprs_and_scores
end
