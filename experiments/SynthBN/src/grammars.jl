using AbstractTrees: Leaves

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

function _add_variables(grammar, num_vars::Int)
    for i = 1:num_vars
        add_rule!(grammar, :(Var = Atom($i)))
    end
end

function build_cnf_grammar(num_vars::Int)
    grammar = deepcopy(conjunctive)
    _add_variables(grammar, num_vars)

    return grammar
end

function build_dnf_grammar(num_vars::Int)
    grammar = deepcopy(disjunctive)
    _add_variables(grammar, num_vars)

    return grammar
end

function count_neighbors_in_expr(r::AbstractRuleNode, grammar::ContextSensitiveGrammar)
    leaves_in_expr = Set(map(x -> x.ind, Leaves(r)))
    terminal_indices = findall(grammar.isterminal)

    return count(x -> x in terminal_indices, leaves_in_expr)
end
