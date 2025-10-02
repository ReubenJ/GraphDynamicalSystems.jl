module JSONExt
import JSON

using GraphDynamicalSystems: Asynchronous, QualitativeNetwork, default_target_function
using Graphs: SimpleDiGraph, add_edge!, add_vertex!
using MacroTools: @capture, postwalk
using MetaGraphsNext: MetaGraph, inneighbor_labels

function nested_dicts_keys_to_lowercase(d)
    if d isa AbstractDict
        return Dict([lowercase(k) => nested_dicts_keys_to_lowercase(v) for (k, v) in d])
    elseif d isa AbstractVector
        return [nested_dicts_keys_to_lowercase(v) for v in d]
    else
        return d
    end
end

function sanitize_formula(f)
    # surround variable names with quotes
    return replace(f, r"var\(([^\)]+)\)" => s"var(\"\1\")")
end

function entity_name_from_in_neighbors(entity, in_neighbors)
    # the formulas can reference their incoming edges
    # with either the name of the neighbor entity or
    # its id
    e_id = tryparse(Int, entity)

    entity_name = [
        Symbol("$(name)_$id") for
        (id, name, _) in in_neighbors if isnothing(e_id) ? name == entity : id == e_id
    ]

    if length(entity_name) != 1
        error(
            "Error while constructing name for entity: $entity, with in neighbors: $in_neighbors",
        )
    end
    return only(entity_name)
end

function create_target_function(
    variable::Dict,
    in_neighbor_ids::Vector{Int},
    id_to_name::Dict,
    mg::MetaGraph,
)
    formula = Meta.parse(sanitize_formula(variable["formula"]))
    in_neighbor_names = getindex.((id_to_name,), in_neighbor_ids)
    in_neighbor_types = getindex.((mg.edge_data,), in_neighbor_ids, (variable["id"],))
    in_neighbors = zip(in_neighbor_ids, in_neighbor_names, in_neighbor_types)

    if isnothing(formula) # default target function
        if length(in_neighbor_ids) == 0
            @warn "$(variable["name"]) has no inputs, defaulting formula to lowest value ($(variable["rangefrom"]))."
            return variable["rangefrom"]
        else
            activators = [
                Symbol("$(name)_$id") for
                (id, name, ty) in in_neighbors if ty == "Activator"
            ]
            inhibitors = [
                Symbol("$(name)_$id") for
                (id, name, ty) in in_neighbors if ty == "Inhibitor"
            ]
            return default_target_function(
                variable["rangefrom"],
                variable["rangeto"],
                activators,
                inhibitors,
            )
        end
    else # custom target function
        return postwalk(
            x ->
                @capture(x, var(v_String)) ?
                :($(entity_name_from_in_neighbors(v, in_neighbors))) : x,
            formula,
        )
    end
end

function to_from_variable_id(r, from_to)
    k = "$(from_to)variable"
    k_w_id = k * "id"

    if haskey(r, k)
        return r[k]
    elseif haskey(r, k_w_id)
        return r[k_w_id]
    else
        @show keys(r)
        error("""
              Neither alternative key was found to retrieve the edge variable id. The \
              model file is not using the expected structure for BMA models.
              """)
    end
end

function QualitativeNetwork(bma_file_path::AbstractString)
    json_def = JSON.parse(read(bma_file_path, String))

    json_def = nested_dicts_keys_to_lowercase(json_def)
    model = json_def["model"]
    variables = model["variables"]
    relationships = model["relationships"]

    id_to_name = Dict([v["id"] => v["name"] for v in variables])
    names = [Symbol("$(v["name"])_$(v["id"])") for v in variables]
    mg = MetaGraph(SimpleDiGraph(), Int, Union{Expr,Integer,Symbol}, String)

    foreach(id_to_name) do (id, n)
        # adding an empty expression: :()
        # because we need to construct the interaction graph
        # first before parsing the functions correctly
        added = add_vertex!(mg, id, :())
        if !added
            error(
                """
                Failed to add the entity ($n, id: $id) from the input file while \
                constructing the QN. Check that there is only one entity in the model with \
                the id $id.
                """,
            )
        end
    end

    foreach(relationships) do r
        from = to_from_variable_id(r, "from")
        to = to_from_variable_id(r, "to")
        type_of_edge = r["type"]
        added = add_edge!(mg, from, to, type_of_edge)
        if !added
            @warn """
            Encountered a duplicate relationship between entities (from: \
            $(id_to_name[from]), #$from; to: $(id_to_name[to]), #$to) while constructing \
            the QN.
            """
        end
    end

    formulas = Union{Expr,Integer,Symbol}[
        create_target_function(v, collect(inneighbor_labels(mg, v["id"])), id_to_name, mg) for v in variables
    ]

    # @show formulas
    # formulas = Union{Expr,Integer,Symbol}[v["formula"] for v in variables]
    domains = [v["rangefrom"]:v["rangeto"] for v in variables]
    #
    return QualitativeNetwork(names, formulas, domains; schedule = Asynchronous)
end
end
