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

function interpret(
    e::Union{AbstractString,Integer,Expr},
    qn_state::AbstractVector{<:Integer},
    vertex_names::AbstractVector{<:AbstractString},
)
    state_map = Dict(zip(vertex_names, deepcopy(qn_state)))

    _int(e) = @match e begin
        ::AbstractString => state_map[e]
        ::Integer => e
        :($v1 + $v2) => _int(v1) + _int(v2)
        :($v1 - $v2) => _int(v1) - _int(v2)
        :($v1 / $v2) => _int(v1) / _int(v2)
        :($v1 * $v2) => _int(v1) * _int(v2)
        :(Min($v1, $v2)) => min(_int(v1), _int(v2))
        :(Max($v1, $v2)) => max(_int(v1), _int(v2))
        :(Ceil($v)) => ceil(_int(v))
        :(Floor($v)) => floor(_int(v))
        _ => error("Unhandled Expr in `interpret`: $e, $(typeof(e))")
    end

    return _int(e)
end

function evaluate_bn(problem::UndirectedProblem, expr, vertex_names)
    sat_examples = BitVector[]

    function _eval_1_dir(in, out)
        truth = TruthDict(Dict(zip(vertex_names, in[:state])))
        res = interpret(expr, truth)
        expected = BooleanTruth(out[:state][findfirst(==(problem.name), vertex_names)])
        success = expected == res

        return success
    end

    for example ∈ problem.examples
        success_direction1 = _eval_1_dir(example.data1, example.data2)
        success_direction2 = _eval_1_dir(example.data2, example.data1)

        success = BitVector([success_direction1, success_direction2])

        push!(sat_examples, success)
    end

    return sat_examples
end

function evaluate_qn(problem::UndirectedProblem, expr, vertex_names)
    sat_examples = BitVector[]

    function _eval_1_dir(in, out)
        res = interpret(expr, in[:state], vertex_names)
        expected = out[:state][findfirst(==(problem.name), vertex_names)]
        success = expected == res

        return success
    end

    for example ∈ problem.examples
        success_direction1 = _eval_1_dir(example.data1, example.data2)
        success_direction2 = _eval_1_dir(example.data2, example.data1)

        success = BitVector([success_direction1, success_direction2])

        push!(sat_examples, success)
    end

    return sat_examples
end
