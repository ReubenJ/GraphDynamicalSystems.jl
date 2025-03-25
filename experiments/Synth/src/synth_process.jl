using Graphs: nv
using Attractors: AttractorsViaRecurrences, basins_of_attraction
using DynamicalSystems: set_distance
using Random: seed!

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

        sat_examples = nothing
        try
            sat_examples = evaluator(problem, expr, vertex_names)
        catch e
            @error "Problem evaluating: Problem name $(problem.name), expr: $expr, i: $i."
            rethrow(e)
        end

        if isnothing(sat_examples)
            push!(exprs_and_scores, (expr, nothing, nothing, i))
            # if all examples worked in at least one direction
        elseif sum(all.(==(false), sat_examples)) == 0
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

rules(g) = g.rules
types(g) = g.types

function get_basins_qn(model)
    async_qn = aqn(model, 1)

    grid = Tuple(range(0, 1) for _ = 1:nv(model))

    mapper = AttractorsViaRecurrences(async_qn, grid; consecutive_recurrences = 1000)

    basins = basins_of_attraction(mapper, grid)

    return basins
end

function get_basins_bn(model)
    async_bn = abn(model)

    grid = Tuple(range(0, 1) for _ = 1:nv(model))

    mapper = AttractorsViaRecurrences(async_bn, grid; consecutive_recurrences = 1000)

    basins = basins_of_attraction(mapper, grid)

    return basins
end

function synth_complete_qn(df, id, target_basins; max_iterations = 1000)
    seed!(37)

    df = df[df.id.==id, :]
    @assert allequal(rules.(df.grammar)) && allequal(types.(df.grammar))
    grammar = first(df.grammar)

    function _get_resulting_basins(sol_assignments)

        selected_functions = getindex.(getindex.(df.exprs_and_scores, sol_assignments), 1)
        entity_names_to_functions = Dict(Symbol.(df.vertex) .=> selected_functions)

        qn = GraphDynamicalSystems.update_functions_to_network(
            entity_names_to_functions,
            grammar,
        )

        resulting_basins = get_basins_qn(qn)

        return resulting_basins
    end

    sol_assignments = ones(Int, nrow(df))

    resulting_basins = _get_resulting_basins(sol_assignments)

    best_distance =
        set_distance.(zip(values(resulting_basins[2]), values(target_basins[2]))...)

    i = 0

    while values(target_basins[2]) ∉ values(resulting_basins[2]) && i < max_iterations
        i += 1
        if i % 1000 == 0
            @info "$i iterations, best distance: $best_distance, assigments: $sol_assignments"
        end

        for sol_to_bump in shuffle(eachindex(sol_assignments))
            if length(resulting_basins[2]) == length(target_basins[2])
                current_distance = [
                    set_distance(x1, x2) for (x1, x2) in
                    zip(values(resulting_basins[2]), values(target_basins[2]))
                ]
                if all(current_distance .<= best_distance)
                    @info "new best distance: $current_distance\nassigments: $sol_assignments\n$(getindex.(getindex.(df.exprs_and_scores, sol_assignments), 1))\n"
                    best_distance = current_distance
                end
            end

            sol_assignments[sol_to_bump] = min(
                sol_assignments[sol_to_bump] + 1,
                length(df.exprs_and_scores[sol_to_bump]),
            )
            resulting_basins = _get_resulting_basins(sol_assignments)
        end
    end

    return resulting_basins, sol_assignments
end
