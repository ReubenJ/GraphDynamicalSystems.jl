using DrWatson

@quickactivate "SynthBN"

using DataFrames
using Herb, HerbGrammar, SoleLogics, HerbSpecification, HerbSearch

include(srcdir("gather_bn_data.jl"))
include(srcdir("grammars.jl"))

all_params = Dict(
    "network_size" => 10,
    "max_equation_depth" => 3,
    "iterations" => 1000,
    "repetitions" => 10,
    "seed" => collect(0:9),
)
dicts = dict_list(all_params)

data = Dict()

for (i, d) in enumerate(dicts)
    per_iter_data, file =
        @produce_or_load(get_split_state_space, d, datadir("sims", "specs"))
    data[i] = per_iter_data
end

res = collect_results!(datadir("sims", "specs"))

function evaluate(problem, expr, symboltable)
    sat_examples = 0

    for example ∈ problem.spec
        res = interpret(eval(expr), TruthDict(Dict(enumerate(example.in[:state][1]))))
        sat_examples += res.flag == example.out
    end

    return sat_examples / length(problem.spec)
end

break_after = 10

cnf_grammar = build_cnf_grammar(all_params["network_size"])
dnf_grammar = build_dnf_grammar(all_params["network_size"])


for experiment in eachrow(res)
    # experiment = deepcopy(experiment)
    println("Experiment: ", experiment.seed)

    for (node, examples) in experiment.specifications
        for grammar in [cnf_grammar, dnf_grammar]
            @show node, grammar

            io_examples =
                map(((in, out),) -> IOExample(Dict([:state => in]), out), collect(examples))
            problem = Problem("$node", io_examples)

            iterator = BFSIterator(grammar, :Start, max_depth = 5)
            found = []
            all_ex = []
            found_after = Inf
            for (i, ex) in enumerate(iterator)
                expr = rulenode2expr(ex, grammar)

                symboltable = SymbolTable(grammar, Main)
                score = evaluate(problem, expr, symboltable)

                push!(all_ex, (eval(expr), score))

                if score == 1
                    push!(found, eval(expr))
                end
                if length(found) > break_after
                    found_after = i
                    break
                end
            end

            d = Dict([
                "seed" => experiment.seed,
                "node" => node,
                "found" => found,
                "all_ex" => all_ex,
                "break_after" => break_after,
                "found_after" => found_after,
                "grammar" => grammar,
                "grammar_type" => grammar == cnf_grammar ? "cnf" : "dnf",
            ])
            @tagsave(datadir("exp_raw", "cnf_search", savename(d, "cnf_search.jld2")), d)
        end
    end
end
