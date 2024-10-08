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
    "max_neighbors" => 3,
    "max_depth" => 7,
    "max_iterations" => 100_000,
    "grammar" => [cnf_grammar, dnf_grammar],
    "grammar_type" => Derived("grammar", x -> x == cnf_grammar ? "cnf" : "dnf"),
    "iterator_type" => BFSIterator,
)

for params in dict_list(synth_params)
    @unpack seed, grammar_type, specifications = params
    @info "Synthesizing for seed $seed, grammar $grammar_type"

    # Create Problem for each node
    for (node, examples) in specifications
        problem = examples_to_problem(node, examples)

        # Synthesize
        @unpack grammar, max_neighbors, max_iterations = params
        @unpack max_depth, iterator_type = params
        iterator = iterator_type(grammar, :Start, max_depth = max_depth)
        exprs_and_scores = synth(problem, iterator, grammar, max_neighbors, max_iterations)

        # Save output
        save_data = copy(params)
        delete!(save_data, "specifications")
        save_data["node"] = node
        save_data["examples"] = examples
        save_data["exprs_and_scores"] = exprs_and_scores
        file_name = savename(save_data, "cnf_search.jld2")
        @tagsave(datadir("exp_raw", "cnf_search", file_name), save_data)
    end
end
