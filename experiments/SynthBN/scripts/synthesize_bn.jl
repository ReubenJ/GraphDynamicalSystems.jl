using DrWatson

@quickactivate "SynthBN"

using DataFrames

include(srcdir("gather_bn_data.jl"))

all_params = Dict(
    "network_size" => 10,
    "max_equation_depth" => 3,
    "iterations" => 1000,
    "repetitions" => 10,
    "seed" => collect(0:9),
)
dicts = dict_list(all_params)

@show dicts

data = Dict()

for (i, d) in enumerate(dicts)
    per_iter_data, file =
        @produce_or_load(get_split_state_space, d, datadir("sims", "specs"))
    data[i] = per_iter_data
end

res = collect_results!(datadir("sims", "specs"))

using Herb, HerbGrammar, SoleLogics, HerbSpecification, HerbSearch

function evaluate(problem, expr, symboltable)
    sat_examples = 0

    for example ∈ problem.spec
        res = interpret(eval(expr), TruthDict(Dict(enumerate(example.in[:state]))))
        sat_examples += res.flag == example.out
    end

    return sat_examples / length(problem.spec)
end

cnf_grammar = @cfgrammar begin
    CNF = Disj ∧ CNF
    CNF = Disj
    Disj = Lit ∨ Disj
    Disj = Lit
    Lit = Var
    Lit = ¬Var
end

for i = 1:all_params["network_size"]
    add_rule!(cnf_grammar, :(Var = Atom($i)))
end

break_after = 10

for experiment in eachrow(res)
    println("Experiment: ", experiment.seed)

    for (node, examples) in experiment.specifications
        println("Node: ", node)

        io_examples =
            map(((in, out),) -> IOExample(Dict([:state => in]), out), collect(examples))
        problem = Problem("$node", io_examples)

        iterator = BFSIterator(cnf_grammar, :CNF, max_depth = 5)
        found = []
        all_ex = []
        found_after = Inf
        for (i, ex) in enumerate(iterator)
            expr = rulenode2expr(ex, cnf_grammar)

            symboltable = SymbolTable(cnf_grammar, Main)
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
        ])
        @tagsave(datadir("exp_raw", "cnf_search", savename(d, "cnf_search.jld2")), d)
    end
end
