function synth(problem, iterator, grammar, max_neighbors, max_iterations)
    exprs_and_scores = []

    largest_n_neighbors_explored = 0

    for (i, ex) in enumerate(iterator)
        if i % 1000 == 0
            @info "$i iterations, up to $largest_n_neighbors_explored neighbors explored"
        end

        n_neighbors = count_neighbors_in_expr(ex, grammar)

        if n_neighbors > largest_n_neighbors_explored
            largest_n_neighbors_explored = n_neighbors
        end

        if n_neighbors > max_neighbors
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

function synth_biodivine(problem, iterator, grammar, max_iterations)
    exprs_and_scores = []

    for (i, ex) in enumerate(iterator)
        if i % 1000 == 0
            @info "$i iterations, problem $(problem.name)"
        end

        expr = rulenode2expr(ex, grammar)

        score = evaluate_bn(problem, expr)

        if score > 0
            push!(exprs_and_scores, (eval(expr), score, i))
        end

        if i > max_iterations
            @warn "Maximum iterations reached"
            break
        end
    end

    return exprs_and_scores
end
