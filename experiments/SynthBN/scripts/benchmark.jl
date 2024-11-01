using DrWatson

@quickactivate :SynthBN

using BenchmarkTools
using SoleLogics
using MLStyle

import SoleLogics.interpret

function interpret(φ::Expr, i::SoleLogics.AbstractInterpretation, args...; kwargs...)
    syntax_branch = @match φ begin
        Expr(:call, :Atom, val) => interpret(Atom(val), i, args...; kwargs...)
        Expr(:call, :∨, children...) => interpret(
            SyntaxBranch(∨, [interpret(ch, i, args...; kwargs...) for ch in children]...),
            i,
            args...;
            kwargs...,
        )
        Expr(:call, :∧, children...) => interpret(
            SyntaxBranch(∧, [interpret(ch, i, args...; kwargs...) for ch in children]...),
            i,
            args...;
            kwargs...,
        )
        Expr(:call, :¬, child) => interpret(
            SyntaxBranch(¬, interpret(child, i, args...; kwargs...)),
            i,
            args...;
            kwargs...,
        )
        _ => error("missing a match for $φ")
    end

    return interpret(syntax_branch, i, args...; kwargs...)
end

function benchmark()
    exprs = [
        :(
            Atom(0) ∨ Atom(1) ∨ Atom(1) ∨ Atom(1) ∨ Atom(1) ∨ Atom(1) ∨ Atom(1) ∨ Atom(1) ∨ Atom(1) ∨ Atom(1)
        ),
        :(Atom("a") ∨ Atom("b")),
        :(
            (¬Atom("v_cGSH_GSSG_b1") ∧ Atom("v_cGR_b1")) ∨
            (Atom("v_cGSH_GSSG_b1") ∧ ¬Atom("v_cGSH_GSSG_b2") ∧ Atom("v_cGR_b1")) ∨
            (Atom("v_cGSH_GSSG_b1") ∧ Atom("v_cGSH_GSSG_b2"))
        ),
        :((¬Atom(1) ∧ Atom(2)) ∨ (Atom(3) ∧ ¬Atom(4) ∧ Atom(5)) ∨ (Atom(6) ∧ Atom(7))),
    ]

    for expr in exprs
        syntax_branch = eval(expr)

        td = TruthDict([0 => ⊤, 1 => ⊤])

        eval_version = @benchmarkable interpret(eval($expr), $td)
        custom_eval_version = @benchmarkable interpret($expr, $td)
        no_eval_version = @benchmarkable interpret($syntax_branch, $td)

        @info "Tuning"
        tune!(eval_version)
        tune!(custom_eval_version)
        tune!(no_eval_version)

        @info "Running"
        m_eval = median(run(eval_version))
        m_custom_eval = median(run(custom_eval_version))
        m_no_eval = median(run(no_eval_version))

        @info "Normal Eval vs. No Eval at all"
        @info judge(m_eval, m_no_eval)

        @info "Custom interpret without eval vs normal interpret without eval"
        @info judge(m_custom_eval, m_no_eval)

        @info "Custom interpret vs. just eval"
        @info judge(m_custom_eval, m_eval)
    end

end

benchmark()
