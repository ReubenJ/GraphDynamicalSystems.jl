using JSON
using MLStyle
import HerbGrammar: expr2rulenode

function load_bma_file(json_model_path::AbstractString)
    model = open(json_model_path, "r") do io
        JSON.parse(io)["Model"]
    end

    # Parse range (N) of activation levels
    variables = model["Variables"]
    ranges_from = getindex.(variables, "RangeFrom")
    ranges_to = getindex.(variables, "RangeTo")
    ranges_to = filter(x -> x > 0, ranges_to)

    @assert allequal(ranges_from) && allequal(ranges_to) "Varying ranges of activation levels across variables is not currently supported. `RangeFrom` values: $(unique(ranges_from)), `RangeTo` values: $(unique(ranges_to))"

    activation_level_bounds = (ranges_from[1], ranges_to[1])
    N = activation_level_bounds[2] - activation_level_bounds[1]

    # Parse each variable/vertex/node in the model
    node_ids = getindex.(variables, "Id")
    @assert allunique(node_ids) "Cannot have duplicate node ids in the model"
    node_names = getindex.(variables, "Name")
    node_names = string.(node_names, "_id_", node_ids)
    node_names = replace.(node_names, "-" => "_")
    node_names = Symbol.(node_names)
    @assert allunique(node_names) "Cannot have duplicate node names in the model. $([(i, count(==(i), node_names)) for i in unique(node_names)])"
    node_fns = getindex.(variables, "Formula")

    id_to_name = Dict(zip(node_ids, node_names))
    grammar = build_qn_grammar(node_names, 0:N)
    grammar_style_exprs = bma_vars_to_grammar_style(id_to_name).(node_fns)

    # The following is also a sanity check that we have the right grammar
    normalized_exprs = Union{Expr,Symbol,Int}[
        if isnothing(e)
            :()
        else
            rulenode2expr(expr2rulenode(e, grammar), grammar)
        end for e in grammar_style_exprs
    ]
    name_to_expr = Dict(zip(node_names, normalized_exprs))
    network = update_functions_to_network(name_to_expr, grammar)

    if network.graph.ne != model["Relationships"]
        @warn "Constructed network does not have the same number of **edges** as the input model."
    end

    if length(network.vertex_labels) != length(variables)
        @warn "Constructed network does not have the same number of **nodes** as the input model."
    end

    system = aqn(network, N)

    return system
end

bma_vars_to_grammar_style(id_to_name::AbstractDict{<:Integer,Symbol}) =
    x -> bma_vars_to_grammar_style(id_to_name, x)
bma_vars_to_grammar_style(id_to_name, fn::String) =
    bma_vars_to_grammar_style(id_to_name, Meta.parse(fn))
bma_vars_to_grammar_style(_, ::Nothing) = nothing
bma_vars_to_grammar_style(_, i::Integer) = i
bma_vars_to_grammar_style(_, s::Symbol) = s

function bma_vars_to_grammar_style(id_to_name::AbstractDict{<:Integer,Symbol}, fn::Expr)
    @match fn begin
        :(var($id)) => id_to_name[id]
        _ => Expr(fn.head, bma_vars_to_grammar_style(id_to_name).(children(fn))...)
    end

end
