using DrWatson

@quickactivate "SynthBN"

using DataFrames
using Herb, HerbGrammar, SoleLogics, HerbSpecification, HerbSearch

include(srcdir("gather_bn_data.jl"))  # So that all dependencies are also loaded when loading results
include(srcdir("grammars.jl"))

include(srcdir("synth_process.jl"))
include(srcdir("evaluator.jl"))
include(srcdir("create_problem.jl"))

res = collect_results!(datadir("sims", "specs"))

cnf_grammar = build_cnf_grammar(res.network_size[1])
dnf_grammar = build_dnf_grammar(res.network_size[1])

synth_params = Dict(
    "seed" => res.seed,
    "specifications" => Derived(
        "seed",
        seed -> filter(row -> row.seed == seed, res)[!, :specifications][1],
    ),
    "break_after" => Inf,
    "max_neighbors" => 5,
    "max_iterations" => 100_000,
    "grammar" => [cnf_grammar, dnf_grammar],
    "grammar_type" => Derived("grammar", x -> x == cnf_grammar ? "cnf" : "dnf"),
)

for params in dict_list(synth_params)
    @unpack seed, grammar_type, specifications = params
    @info "Synthesizing for seed $seed, grammar $grammar_type"

    # Create Problem for each node
    for (node, examples) in specifications
        problem = examples_to_problem(node, examples)

        # Synthesize
        @unpack grammar, max_neighbors, max_iterations = params
        iterator = BFSIterator(grammar, :Start, max_depth = 5)
        exprs_and_scores = synth(problem, iterator, grammar, max_neighbors, max_iterations)

        save_data = copy(params)
        save_data["exprs_and_scores"] = exprs_and_scores
        file_name = savename(save_data, "cnf_search.jld2")
        @tagsave(datadir("exp_raw", "cnf_search", file_name), save_data)
    end
end


# for experiment in eachrow(res)
#     @info "Experiment: $(experiment.seed)"

#     for (node, examples) in experiment.specifications
#         # @info "Processing node $node"
#         for grammar in [cnf_grammar, dnf_grammar]
#             io_examples =
#                 map(((in, out),) -> IOExample(Dict([:state => in]), out), collect(examples))
#             problem = Problem("$node", io_examples)

#             iterator = BFSIterator(grammar, :Start, max_depth = 5)
#             found = []
#             all_ex = []
#             found_after = Inf
#             for (i, ex) in enumerate(iterator)
#                 expr = rulenode2expr(ex, grammar)

#                 symboltable = SymbolTable(grammar, Main)
#                 score = evaluate(problem, expr, symboltable)

#                 push!(all_ex, (eval(expr), score))

#                 if score == 1
#                     push!(found, eval(expr))
#                 end
#                 if length(found) > break_after
#                     found_after = i
#                     break
#                 end
#             end
#             @show length(found)

#             d = Dict([
#                 "seed" => experiment.seed,
#                 "node" => node,
#                 "found" => found,
#                 "all_ex" => all_ex,
#                 "break_after" => break_after,
#                 "found_after" => found_after,
#                 "grammar" => grammar,
#                 "grammar_type" => grammar == cnf_grammar ? "cnf" : "dnf",
#             ])
#             @tagsave(datadir("exp_raw", "cnf_search", savename(d, "cnf_search.jld2")), d)
#         end
#     end
# end
