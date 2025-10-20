module BMA

import GraphDynamicalSystems
import GraphDynamicalSystems:
    Asynchronous,
    EntityIdName,
    QN,
    QualitativeNetwork,
    ScheduleStyle,
    Synchronous,
    default_target_function,
    domain,
    entities,
    get_domain,
    get_graph,
    id,
    name,
    range_from,
    range_to,
    target_function,
    target_functions
import Graphs: SimpleDiGraph, add_edge!, add_vertex!
import JSON
import MLStyle: @match
import MetaGraphsNext: MetaGraph, edge_labels, inneighbor_labels, labels
import StructUtils

using DocStringExtensions
using MacroTools: @capture, postwalk

StructUtils.@tags struct Relationship
    id::Int & (json = (name = "id",),)
    from::Int & (json = (name = "fromvariable",),)
    to::Int & (json = (name = "tovariable",),)
    type::String & (json = (name = "type",),)
end

GraphDynamicalSystems.id(r::Relationship) = r.id
from(r::Relationship) = r.from
to(r::Relationship) = r.to
type(r::Relationship) = r.type

StructUtils.@defaults struct Entity
    target_function::Any & (json = (name = "formula",),)
    id::Int & (json = (name = "id",),)
    range_from::Int & (json = (name = "rangefrom",),)
    range_to::Int & (json = (name = "rangeto",),)
    name::String = "" & (json = (name = "name",),)
end
GraphDynamicalSystems.id(e::Entity) = e.id
target_function(e::Entity) = e.target_function
range_from(e::Entity) = e.range_from
range_to(e::Entity) = e.range_to
GraphDynamicalSystems.name(e::Entity) = e.name

function GraphDynamicalSystems.Entity(e::Entity)
    GraphDynamicalSystems.Entity(
        (id(e), name(e)),
        target_function(e),
        range_from(e):range_to(e),
    )
end

StructUtils.@tags struct Model
    entities::Vector{Entity} & (json = (name = "variables",),)
    relationships::Vector{Relationship}
end
entities(m::Model) = m.entities
relationships(m::Model) = m.relationships

struct BMAInputFormat
    model::Model
    # layout is not needed here
    # and thus ignored
end
model(bma::BMAInputFormat) = bma.model

function bma_dict_to_qn(bma_model::Model)
    bma_entities = GraphDynamicalSystems.Entity.(entities(bma_model))
    bma_relationships = relationships(bma_model)

    names = name.(bma_entities)
    id_to_name = Dict(id.(bma_entities) .=> names)
    mg = MetaGraph(SimpleDiGraph(), Int, Union{Expr,Integer,Symbol}, String)

    foreach(bma_entities) do v
        # adding an empty expression: :()
        # because we need to construct the interaction graph
        # first before parsing the functions correctly
        added = add_vertex!(mg, id(v), :())
        if !added
            error(
                """
                Failed to add the entity (\"$(name(v))\", id: #$(id(v))) from the input file while \
                constructing the QN. Check that there is only one entity in the model with \
                the id #$(id(v)).
                """,
            )
        end
    end

    foreach(bma_relationships) do r
        if from(r) ∉ labels(mg) || to(r) ∉ labels(mg)
            error("Either the source or destination of the edge is not in the graph.")
        end
        added = add_edge!(mg, from(r), to(r), type(r))
        if !added
            @warn """
            Could not create an edge between entities (from: \
            #$(from(r)); to: #$(to(r))) while constructing \
            the QN.
            """
        end
    end

    entities_with_functions = [
        GraphDynamicalSystems.Entity(
            (id(e), name(e)),
            create_target_function(
                e,
                collect(inneighbor_labels(mg, id(e))),
                id_to_name,
                mg,
            ),
            domain(e),
        ) for e in bma_entities
    ]

    return QualitativeNetwork(entities_with_functions; schedule = Synchronous)
end

"""
    $(SIGNATURES)

Classify all symbols in `ex` as activators or inhibitors.

## Examples


"""
function classify_activators_inhibitors(ex, sign = 1, activators = [], inhibitors = [])
    (activators, inhibitors) = @match ex begin
        ::Symbol => if sign == 1
            (push!(activators, ex), inhibitors)
        else
            (activators, push!(inhibitors, ex))
        end
        ::Int => (activators, inhibitors)
        Expr(:call, :(-), child) =>
            classify_activators_inhibitors(child, -sign, activators, inhibitors)
        Expr(:call, :(-), left_child, right_child) => begin
            (activators, inhibitors) = classify_activators_inhibitors(
                left_child,
                sign,
                activators,
                inhibitors,
            )
            (activators, inhibitors) = classify_activators_inhibitors(
                right_child,
                -sign,
                activators,
                inhibitors,
            )
            (activators, inhibitors)
        end
        Expr(:call, f, children...) => begin
            for child in children
                (activators, inhibitors) = classify_activators_inhibitors(
                    child,
                    sign,
                    activators,
                    inhibitors,
                )
            end
            (activators, inhibitors)
        end
        Expr(expr_type, _...) => error("Can't classify expression of type $expr_type")
    end

    return activators, inhibitors
end

function classify_activators_inhibitors(d::AbstractDict)
    return Dict(e => classify_activators_inhibitors(fn) for (e, fn) in d)
end

function swap_entity_names_to_var_ids(ex)
    @match ex begin
        ::Symbol && if (ex ∉ [:+, :-, :/, :*, :min, :max, :ceil, :floor])
        end => :(var($(parse(Int, last(rsplit(string(ex), "_"; limit = 2))))))
        Expr(:call, op, children...) =>
            Expr(:call, op, swap_entity_names_to_var_ids.(children)...)
        _ => ex
    end
end

"""
    stringify_fn(ex, lower_bound, upper_bound)

Take an `ex` and if it's of the form of a default function, return "".
"""
function stringify_fn(ex, lower_bound, upper_bound)
    if is_default_function(ex, lower_bound, upper_bound)
        return ""
    else
        string(ex)
    end
end

function is_default_function(ex, lower_bound, upper_bound)
    @match ex begin
        # no inputs
        -1 => true
        # single activator
        :(var($id)) => true

        # multiple activators
        Expr(:call, :/, Expr(:call, :+, vars...), denom) && (
            if length(vars) == denom
            end
        ) => true

        # only inhibitor(s)
        :($bound - $inh) && (
            if bound == upper_bound
            end
        ) => is_default_function(inh, lower_bound, upper_bound)

        # both inhibitor(s) and activator(s)
        :(max($bound, $act - $inh)) && (
            if bound == lower_bound
            end
        ) =>
            is_default_function(act, lower_bound, upper_bound) &&
            is_default_function(inh, lower_bound, upper_bound)
        _ => false
    end
end

"""
    $(SIGNATURES)

Write QN to a dictionary to output as JSON.

Use `JSON.json(qn)` directly to convert to JSON.
"""
function qn_to_bma_dict(qn::QN{N,S,M}) where {N,S,C,G,L<:EntityIdName,M<:MetaGraph{C,G,L}}
    lower_upper = extrema.(get_domain(qn))
    ids = id.(entities(qn))
    entity_names = name.(entities(qn))
    functions = [target_functions(qn)[e] for e in entities(qn)]
    activator_inhibitor_pairs = classify_activators_inhibitors(target_functions(qn))
    functions = swap_entity_names_to_var_ids.(functions)
    functions = stringify_fn.(functions, first.(lower_upper), last.(lower_upper))

    variables = [
        Dict(
            "RangeFrom" => d[1],
            "RangeTo" => d[2],
            "Id" => i,
            "Formula" => f,
            "Name" => n,
        ) for (d, i, n, f) in zip(lower_upper, ids, entity_names, functions)
    ]
    relationships = [
        Dict(
            "Id" => i,
            "FromVariable" => id(src),
            "ToVariable" => id(dst),
            "Type" => let (activators, inhibitors) = activator_inhibitor_pairs[dst]
                activators_transformed = EntityIdName.(activators)
                inhibitors_transformed = EntityIdName.(inhibitors)
                if src in activators_transformed
                    "Activator"
                elseif src in inhibitors_transformed
                    "Inhibitor"
                else
                    error(
                        "Malformed edge. $src not found in activators ($activators_transformed) or inhibitors ($inhibitors_transformed).",
                    )
                end
            end,
        ) for (i, (src, dst)) in enumerate(edge_labels(get_graph(qn)))
    ]
    output_dict = Dict(
        "Model" => Dict("Variables" => variables, "Relationships" => relationships),
        "Layout" => Dict(
            "Variables" =>
                [Dict("Id" => v["Id"], "Name" => v["Name"]) for v in variables],
        ),
    )

    return output_dict
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
            """
            Error while constructing name for entity: $entity, with in neighbors: \
            $in_neighbors. There are more than one incoming neighbor entities with the same \
            name. To fix this error, remove the erroneous relationships from the JSON file, \
            or reference the entity by id (like `var(3)`).
            """,
        )
    end
    return only(entity_name)
end

function create_target_function(
    variable::GraphDynamicalSystems.Entity{EntityIdName{S},Int},
    in_neighbor_ids::Vector{Int},
    id_to_name::Dict,
    mg::MetaGraph,
) where {S}
    formula = Meta.parse(sanitize_formula(target_function(variable)))
    in_neighbor_names = getindex.((id_to_name,), in_neighbor_ids)
    in_neighbor_types = getindex.((mg.edge_data,), in_neighbor_ids, (id(variable),))
    in_neighbors = zip(in_neighbor_ids, in_neighbor_names, in_neighbor_types)

    if isnothing(formula) # default target function
        if length(in_neighbor_ids) == 0
            @warn "$(name(variable)) has no inputs, defaulting formula to -1"
            return -1
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
                range_from(variable),
                range_to(variable),
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

function nested_dicts_keys_to_lowercase(d)
    if d isa AbstractDict
        return Dict([lowercase(k) => nested_dicts_keys_to_lowercase(v) for (k, v) in d])
    elseif d isa AbstractVector
        return [nested_dicts_keys_to_lowercase(v) for v in d]
    else
        return d
    end
end

function QualitativeNetwork(bma_file_path::AbstractString)
    bma_def_raw = JSON.parsefile(bma_file_path)
    bma_def_raw = nested_dicts_keys_to_lowercase(bma_def_raw)
    bma_def = JSON.parse(JSON.json(bma_def_raw), BMAInputFormat)
    bma_model = model(bma_def)

    return bma_dict_to_qn(bma_model)
end

function JSON.json(qn::QualitativeNetwork)
    return JSON.json(qn_to_bma_dict(qn); omit_empty = false)
end
JSON.json(io_or_filename, qn::T) where {T<:QualitativeNetwork} =
    JSON.json(io_or_filename, qn_to_bma_dict(qn); omit_empty = false)
JSON.json(io::IO, qn::T) where {T<:QualitativeNetwork} =
    JSON.json(io, qn_to_bma_dict(qn); omit_empty = false)

end
