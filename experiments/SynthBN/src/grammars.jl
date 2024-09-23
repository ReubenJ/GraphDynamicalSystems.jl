function build_cnf_grammar(num_vars::Int)
    grammar = @cfgrammar begin
        CNF = Disj ∧ CNF
        CNF = Disj
        Disj = Lit ∨ Disj
        Disj = Lit
        Lit = Var
        Lit = ¬Var
    end

    for i = 1:num_vars
        add_rule!(grammar, :(Var = Atom($i)))
    end

    return grammar
end

function build_dnf_grammar(num_vars::Int)
    grammar = @cfgrammar begin
        DNF = Conj ∨ DNF
        DNF = Conj
        Conj = Lit ∧ Conj
        Conj = Lit
        Lit = Var
        Lit = ¬Var
    end

    for i = 1:num_vars
        add_rule!(grammar, :(Var = Atom($i)))
    end

    return grammar
end
