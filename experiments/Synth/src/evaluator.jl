using MLStyle: @match
using SoleLogics
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

function evaluate_bn(problem, expr)
    sat_examples = 0

    for example ∈ problem.spec
        truth = TruthDict(Dict(enumerate(example.in[:state])))
        res = interpret(expr, truth)
        sat_examples += res.flag == example.out
    end

    return sat_examples / length(problem.spec)
end
