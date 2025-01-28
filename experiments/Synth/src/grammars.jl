using AbstractTrees: Leaves
using AbstractTrees
using HerbConstraints: StateHole, freeze_state
using HerbCore: get_rule

conjunctive = @cfgrammar begin
    Start = CNF
    CNF = Disj ∧ CNF
    CNF = Disj
    Disj = Lit ∨ Disj
    Disj = Lit
    Lit = Var
    Lit = ¬Var
end

disjunctive = @cfgrammar begin
    Start = DNF
    DNF = Conj ∨ DNF
    DNF = Conj
    Conj = Lit ∧ Conj
    Conj = Lit
    Lit = Var
    Lit = ¬Var
end

function _add_variables(grammar, vars::AbstractVector{<:Union{<:AbstractString,<:Atom}})
    for i in vars
        add_rule!(grammar, :(Var = Atom($i)))
    end
end

function _add_variables(grammar, vars::AbstractVector{<:Integer})
    for i in vars
        add_rule!(grammar, :(Var = Atom($(string(i)))))
    end
end

_add_variables(grammar, num_vars::Int) =
    _add_variables(grammar, string.(collect(1:num_vars)))

function build_cnf_grammar(num_vars::Int)
    grammar = deepcopy(conjunctive)
    _add_variables(grammar, num_vars)

    return grammar
end

function build_cnf_grammar(vars::AbstractVector)
    grammar = deepcopy(conjunctive)
    _add_variables(grammar, vars)

    return grammar
end

function build_dnf_grammar(num_vars::Int)
    grammar = deepcopy(disjunctive)
    _add_variables(grammar, num_vars)

    return grammar
end

function build_dnf_grammar(vars::AbstractVector)
    grammar = deepcopy(disjunctive)
    _add_variables(grammar, vars)

    return grammar
end

function count_neighbors_in_expr(r::AbstractRuleNode, grammar::ContextSensitiveGrammar)
    leaves_in_expr = Set(map(x -> get_rule(x), Leaves(r)))
    terminal_indices = findall(grammar.isterminal)

    return count(x -> x in terminal_indices, leaves_in_expr)
end

AbstractTrees.children(node::StateHole) = node.children
