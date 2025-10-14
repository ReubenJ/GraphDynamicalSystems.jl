import DynamicalSystemsBase: get_state, set_state!
import JSON
import SciMLBase
import StructUtils

using AbstractTrees: Leaves, PostOrderDFS
using DynamicalSystemsBase: ArbitrarySteppable, current_parameters, initial_state
using Graphs: AbstractGraph, SimpleDiGraph, add_edge!, add_vertex!
using HerbConstraints: DomainRuleNode, Forbidden, Ordered, Unique, VarNode, addconstraint!
using HerbCore: AbstractGrammar, RuleNode, get_rule
using HerbGrammar: @csgrammar, add_rule!, rulenode2expr
using HerbSearch: rand
using MLStyle: @match
using MacroTools: @capture, postwalk
using MetaGraphsNext: MetaGraph, add_edge!, edge_labels, inneighbor_labels, labels, nv
using StaticArrays: MVector, SVector

const base_qn_grammar = @csgrammar begin
    Val = Val + Val
    Val = Val - Val
    Val = Val / Val
    Val = Val * Val
    Val = min(Val, Val)
    Val = max(Val, Val)
    Val = ceil(Val)
    Val = floor(Val)
end

const default_qn_constants = [0, 1, 2]

"""
    $(TYPEDSIGNATURES)

Builds a grammar based on the base QN grammar adding `entity_names` and `constants`
to the grammar.

The following constraints are currently included

1. removing symmetry due to commutativity of `+`/`*`/`min`/`max`
2. forbidding same arguments of two argument functions
3. forbidding constant arguments to 2-argument functions
4. forbidding constant arguments to 1-argument functions
5. using each of the entities only once per function
6. forbidding adding or subtracting zero
7. forbidding multiplication and division by 1 or 0
8. forcing the first operator inside `ceil` and `floor` to be `÷`
9. forbidding `max(□, X)` and `min(□, X)` where X is either the max or min
constant in the grammar.

"""
function build_qn_grammar(
    entity_names,
    constants = default_qn_constants;
    unique_constr = true,
)
    g = deepcopy(base_qn_grammar)

    for e in entity_names
        add_rule!(g, :(Val = $e))
    end

    for c in constants
        add_rule!(g, :(Val = $c))
    end

    add_rule!(g, :(Start = Val))

    # +, *, min, max, are all commutative
    domain = BitVector(zeros(length(g.rules)))
    @. domain[[1, 4:6...]] = true
    template_tree = DomainRuleNode(domain, [VarNode(:a), VarNode(:b)])
    order = [:a, :b]

    addconstraint!(g, Ordered(deepcopy(template_tree), order))

    # Forbid same arguments for 2-argument functions
    domain = BitVector(zeros(length(g.rules)))
    @. domain[length(g.childtypes)==2] = true
    template_tree = DomainRuleNode(domain, [VarNode(:a), VarNode(:a)])

    addconstraint!(g, Forbidden(deepcopy(template_tree)))

    # Forbid constant arguments for 2-argument functions
    domain = falses(length(g.rules))
    @. domain[length(g.childtypes)==2] = true
    consts_domain = falses(length(g.rules))
    consts_domain[findall(x -> x isa Int, g.rules)] .= true
    consts_domain_rn = DomainRuleNode(consts_domain)
    template_tree = DomainRuleNode(domain, [consts_domain_rn, consts_domain_rn])

    addconstraint!(g, Forbidden(deepcopy(template_tree)))

    # Forbid constant arguments for 1-argument functions
    domain = falses(length(g.rules))
    @. domain[[7, 8]] = true
    consts_domain = falses(length(g.rules))
    consts_domain[findall(x -> x isa Int, g.rules)] .= true
    consts_domain_rn = DomainRuleNode(consts_domain)
    template_tree = DomainRuleNode(domain, [consts_domain_rn])

    addconstraint!(g, Forbidden(deepcopy(template_tree)))

    n_original_rules = length(base_qn_grammar.rules)

    # Only use each of the entities once per function
    n_consts = length(constants)
    entities = (n_original_rules+1):(length(g.rules)-n_consts)

    if unique_constr
        addconstraint!.((g,), Unique.(entities))
    end

    # Forbid □ + 0, □ - 0
    plus_or_minus = falses(length(g.rules))
    plus_or_minus[[1, 2]] .= true
    zero_rule = findfirst(==(0), g.rules)
    if !isnothing(zero_rule)
        template_tree = DomainRuleNode(plus_or_minus, [VarNode(:a), RuleNode(zero_rule)])

        addconstraint!(g, Forbidden(deepcopy(template_tree)))

        # Both orderings, but only for plus. Allow 0 - □
        plus_or_minus[2] = false
        template_tree = DomainRuleNode(plus_or_minus, [RuleNode(zero_rule), VarNode(:a)])
        addconstraint!(g, Forbidden(deepcopy(template_tree)))
    end

    # Forbid □ * 1, □ / 1, □ * 0, □ / 0
    mult_or_div = falses(length(g.rules))
    mult_or_div[[3, 4]] .= true
    one_zero_domain = falses(length(g.rules))
    one_zero_domain[findfirst(==(1), g.rules)] = true
    if !isnothing(findfirst(==(0), g.rules))
        one_zero_domain[findfirst(==(0), g.rules)] = true
    end

    template_tree =
        DomainRuleNode(mult_or_div, [VarNode(:a), DomainRuleNode(one_zero_domain)])

    addconstraint!(g, Forbidden(deepcopy(template_tree)))

    # Forbid ceil(X) and floor(X) unless X = □ ÷ □
    ceil_or_floor = BitVector(zeros(length(g.rules)))
    ceil_or_floor[[7, 8]] .= true
    all_except_div = trues(length(g.rules))
    all_except_div[3] = false
    template_tree = DomainRuleNode(ceil_or_floor, [DomainRuleNode(all_except_div)])

    addconstraint!(g, Forbidden(deepcopy(template_tree)))

    # Forbid max(□, X) and min(□, X) where X is either the largest or smallest constant in the grammar
    min_max_rules = falses(length(g.rules))
    min_max_rules[[5, 6]] .= true
    (min_const, max_const) = extrema(filter(x -> isa(x, Int), g.rules))
    extrema_domain = falses(length(g.rules))
    extrema_domain[findall(x -> x == min_const || x == max_const, g.rules)] .= true
    rule_extrema_consts = DomainRuleNode(extrema_domain)
    template_tree = DomainRuleNode(min_max_rules, [VarNode(:a), rule_extrema_consts])

    addconstraint!(g, Forbidden(deepcopy(template_tree)))

    return g
end

"""
    $TYPEDSIGNATURES

Construct a default target function for an entity in a QN from a list of
`activators` and `inhibitors`.

Follows the definition given in Eq. 3 of ["Qualitative networks: a symbolic
approach to analyze biological signaling
networks"](https://doi.org/10.1186/1752-0509-1-4).

## Examples

Say we have a component `X` and it has an lower bound on its state value of 0,
an upper bound of 4, activators `A`, `B`, `C`, and inhibitors `D`, `E`, `F`,
then the following example constructs an expression for its default target
function.

```jldoctest
julia> default_target_function(0, 4, [:A, :B, :C], [:D, :E, :F])
:(max(0, (A + B + C) / 3 - (D + E + F) / 3))
```

"""
function default_target_function(
    lower_bound::Integer,
    upper_bound::Integer,
    activators::AbstractVector = [],
    inhibitors::AbstractVector = [],
)
    sum_only_or_nothing = x -> if length(x) == 0
        nothing
    elseif length(x) == 1
        :($(only(x)))
    elseif length(x) > 1
        :($(Expr(:call, :+, x...)) / $(length(x)))
    end

    expr_activators = sum_only_or_nothing(activators)
    expr_inhibitors = sum_only_or_nothing(inhibitors)

    if isnothing(expr_activators) && isnothing(expr_inhibitors)
        error("Constructing a default target function for a QN with no \
              activators or inhibitors.")
    elseif isnothing(expr_activators) # no activators, special case mentioned in paper
        return :($upper_bound - $expr_inhibitors)
    elseif isnothing(expr_inhibitors)
        return :($expr_activators)
    else
        return :(max($lower_bound, $expr_activators - $expr_inhibitors))
    end
end

abstract type EntityLabel end

struct EntityId <: EntityLabel
    id::Int
end
id(e::EntityId) = e.id

struct EntityName{S} <: EntityLabel
    name::S
end
name(e::EntityName) = e.name

struct EntityIdName{S} <: EntityLabel
    id::Int
    name::S
end
id(e::EntityIdName) = e.id
name(e::EntityIdName) = e.name
Base.:(==)(e::EntityIdName, e2::EntityIdName) = id(e) == id(e2) && name(e) == name(e2)

struct Entity{I<:EntityLabel,D}
    label::I
    target_function::Any
    domain::UnitRange{D}
end
Entity(name::Symbol, args...) = Entity(EntityName(name), args...)
Entity(id::Int, args...) = Entity(EntityId(id), args...)
Entity((id, name), args...) = Entity(EntityIdName(id, name), args...)

label(e::Entity) = e.label
id(e::Entity) = id(label(e))
name(e::Entity) = name(label(e))
target_function(e::Entity) = e.target_function
domain(e::Entity) = e.domain
range_from(e::Entity) = first(domain(e))
range_to(e::Entity) = last(domain(e))

function get_used_entities(fn, entities_in_model)
    filter(in(name.(entities_in_model)), collect(Leaves(fn)))
end

"""
    $(TYPEDSIGNATURES)
"""
function update_functions_to_interaction_graph(
    entities_in_model::AbstractVector{<:E},
    schedule = Synchronous,
) where {I,E<:Entity{I}}
    graph = MetaGraph(
        SimpleDiGraph();
        label_type = I,
        vertex_data_type = E,
        graph_data = schedule,
    )
    if !allunique(label.(entities_in_model))
        val_counts = Dict()
        for e in entities_in_model
            val_counts[name(e)] = append!(get(val_counts, name(e), []), [e])
        end
        duplicates = [v for v in values(val_counts) if length(v) > 1]
        error("""The QN implementation only supports models with unique \
              entity name/id combinations.

              Duplicates:

              $duplicates""")
    end

    for entity in entities_in_model
        graph[label(entity)] = entity
    end

    for dst in entities_in_model
        input_entities = get_used_entities(target_function(dst), entities_in_model)
        for src in EntityName.(input_entities)
            l = collect(labels(graph))
            if !(src ∈ l && label(dst) ∈ l)
                error(
                    """Could not add edge from $src to $(label(dst)). The vertex labels in the graph are currently $(collect(labels(graph))).""",
                )
            end
            add_edge!(graph, src, label(dst))
        end
    end

    return graph
end

"""
    $(TYPEDSIGNATURES)
"""
function sample_qualitative_network(
    entities::AbstractVector{Symbol},
    domains::AbstractVector{UnitRange{Int}},
    max_eq_depth::Int;
    schedule = Synchronous,
)
    g = build_qn_grammar(entities, default_qn_constants)
    update_fns = Union{Expr,Integer,Symbol}[
        rulenode2expr(rand(RuleNode, g, :Val, max_eq_depth), g) for _ in entities
    ]

    qn = QualitativeNetwork(Entity.(entities, update_fns, domains); schedule = schedule)

    return qn
end

sample_qualitative_network(N::Int, args...; kwargs...) =
    sample_qualitative_network(Symbol.(('A':'Z')[1:N]), args...; kwargs...)

"""
    $(TYPEDEF)

A qualitative network model as described in ["Qualitative networks: a symbolic approach to
analyze biological signaling networks"](https://doi.org/10.1186/1752-0509-1-4).

This implementation encompasses both the synchronous and asynchonous cases. In the paper, it
is assumed that the synchronous case is used. As such, the default constructor uses a
synchronous schedule.

$(FIELDS)

Systems that include the model semantics wrap around this struct with an
[`ArbitrarySteppable`](https://juliadynamics.github.io/DynamicalSystems.jl/stable/tutorial/#DynamicalSystemsBase.ArbitrarySteppable)
from [`DynamicalSystems`](https://juliadynamics.github.io/DynamicalSystems.jl/stable/). See
[`create_qn_system`](@ref) for an example.
"""
struct QualitativeNetwork{
    N,
    Schedule,
    M<:MetaGraph,
    # EntityLabelType,
    # EntityData{EntityLabelType},
    # EdgeDataType,
} <: GraphDynamicalSystem{N,Schedule}
    "Graph containing the topology and target functions of the network"
    graph::M #MetaGraph{
    #     Int,
    #     SimpleDiGraph{Int},
    #     EntityLabelType,
    #     EntityData{EntityLabelType},
    #     EdgeDataType,
    # } # {Code, Graph type, vert. label, vert data, edge data}
    "State of the network"
    state::MVector{N,Int}

    function QualitativeNetwork(
        graph, #::MetaGraph{
        #     Int,
        #     SimpleDiGraph{Int},
        #     EntityLabelType,
        #     EntityDataType{EntityLabelType},
        #     EdgeDataType,
        # },
        state;
        schedule = Synchronous,
    ) #where {EntityLabelType,EntityDataType,EdgeDataType}
        N = nv(graph)
        if N != length(state)
            error("""The number of entities in the model ($N) must match the \
                  length of the provided state vector ($(length(state))).""")
        end

        return new{
            N,
            schedule(),
            typeof(graph),
            # EntityLabelType,
            # EntityDataType{EntityLabelType},
            # EdgeDataType,
        }(graph, state)
    end
end

function QualitativeNetwork(
    entities::AbstractVector{<:Entity};
    state = nothing,
    schedule = Synchronous,
)
    graph = update_functions_to_interaction_graph(entities, schedule)

    if isnothing(state)
        state = rand.(domain.(entities))
    end

    return QualitativeNetwork(graph, state; schedule)
end

QualitativeNetwork(entities::AbstractVector{<:AbstractString}, args...; kwargs...) =
    QualitativeNetwork(Symbol.(entities), args...; kwargs...)

"""
    $(TYPEDSIGNATURES)

Shorthand for [`QualitativeNetwork`](@ref).
"""
const QN = QualitativeNetwork

StructUtils.@tags struct JSONRelationship
    id::Int & (json = (name = "id",),)
    from::Int & (json = (name = "fromvariable",),)
    to::Int & (json = (name = "tovariable",),)
    type::String & (json = (name = "type",),)
end

id(r::JSONRelationship) = r.id
from(r::JSONRelationship) = r.from
to(r::JSONRelationship) = r.to
type(r::JSONRelationship) = r.type

StructUtils.@tags struct JSONEntity
    target_function::Any & (json = (name = "formula",),)
    id::Int & (json = (name = "id",),)
    range_from::Int & (json = (name = "rangefrom",),)
    range_to::Int & (json = (name = "rangeto",),)
    name::String & (json = (name = "name",),)
end
id(e::JSONEntity) = e.id
target_function(e::JSONEntity) = e.target_function
range_from(e::JSONEntity) = e.range_from
range_to(e::JSONEntity) = e.range_to
name(e::JSONEntity) = e.name

Entity(e::JSONEntity) =
    Entity((id(e), name(e)), target_function(e), range_from(e):range_to(e))

StructUtils.@tags struct JSONModel
    entities::Vector{JSONEntity} & (json = (name = "variables",),)
    relationships::Vector{JSONRelationship}
end
entities(m::JSONModel) = m.entities
relationships(m::JSONModel) = m.relationships

struct JSONBMA
    model::JSONModel
end
model(bma::JSONBMA) = bma.model


function QualitativeNetwork(bma_file_path::AbstractString)
    bma_def_raw = JSON.parsefile(bma_file_path)
    bma_def_raw = nested_dicts_keys_to_lowercase(bma_def_raw)
    bma_def = JSON.parse(JSON.json(bma_def_raw), JSONBMA)
    bma_model = model(bma_def)

    return bma_dict_to_qn(bma_model)
end

function JSON.json(qn::QualitativeNetwork)
    return JSON.json(qn_to_bma_dict(qn))
end

"""
    $(TYPEDSIGNATURES)

Get the domain of the entity `entity_label` in `qn`.
"""
function get_domain(qn::QN, entity_label)
    graph = get_graph(qn)
    entity = graph[entity_label]

    return domain(entity)
end

"""
    $(TYPEDSIGNATURES)

Get all of the domains of the entities in `qn`.
"""
function get_domain(qn::QN)
    return get_domain.((qn,), labels(get_graph(qn)))
end

function _get_entity_index(qn::QN, entity)
    # Ugly, we shouldn't pass entities around as Symbols anymore
    # but this works for now
    # actually, doesn't because there are sometimes variables with underscores... time to rewrite more
    entity_proc = if entity isa EntityName
        split_res = rsplit(String(name(entity)), "_"; limit = 2)
        entity_proc = if length(split_res) == 2
            (entity_str, id_str) = split_res
            id_val = tryparse(Int, id_str)
            if !isnothing(id_val)
                EntityIdName(id_val, entity_str)
            else
                entity
            end
        else
            entity
        end
    else
        entity
    end
    i = findfirst(isequal(entity_proc), entities(qn))
    if isnothing(i)
        error("""Tried to get the state of $entity_proc but could not retrieve it. \
              The entities in the model are $(entities(qn))""")
    end
    return i
end

"""
    $(TYPEDSIGNATURES)
"""
function target_functions(qn::QN)
    return Dict([
        c => target_function(entity) for (c, (_, entity)) in get_graph(qn).vertex_properties
    ])
end

"""
    $(TYPEDSIGNATURES)
"""
function get_state(qn::QN, entity)
    i = _get_entity_index(qn, entity)
    return qn.state[i]
end
get_state(qn::QN, entity::Symbol) = get_state(qn, EntityName(entity))

function _set_state!(qn::QN, entity, value::Integer)
    i = _get_entity_index(qn::QN, entity)
    qn.state[i] = value
end

"""
    $(TYPEDSIGNATURES)
"""
function set_state!(qn::QN, entity, value::Integer)
    max_for_entity = maximum(get_domain(qn, entity))
    if value > max_for_entity
        error(
            "Value ($value) cannot be larger than the maximum level for $entity ($(max_for_entity))",
        )
    end

    _set_state!(qn, entity, value)
end

function set_state!(qn::QN, entity::Symbol, value::Integer)
    set_state!(qn, EntityName(entity), value)
end

"""
    $(TYPEDSIGNATURES)

Interpret target functions from a [`QualitativeNetwork`](@ref).
"""
function interpret(e::Union{Expr,Symbol,Int}, qn::QN)
    @match e begin
        ::Symbol => get_state(qn, e)
        ::Int => e
        :($v1 + $v2) => interpret(v1, qn) + interpret(v2, qn)
        :($v1 - $v2) => interpret(v1, qn) - interpret(v2, qn)
        :($v1 / $v2) => interpret(v1, qn) / interpret(v2, qn)
        :($v1 * $v2) => interpret(v1, qn) * interpret(v2, qn)
        :(min($v1, $v2)) => min(interpret(v1, qn), interpret(v2, qn))
        :(max($v1, $v2)) => max(interpret(v1, qn), interpret(v2, qn))
        :(ceil($v)) => ceil(interpret(v, qn))
        :(floor($v)) => floor(interpret(v, qn))
        _ => error("Unhandled Expr in `interpret`: $e")
    end
end

"""
    $(TYPEDSIGNATURES)

Returns the limited value of `next_value` which is at most 1 different than `prev_value`.

It is also never negative, or larger than `N`.
"""
function limit_change(
    prev_value::Integer,
    next_value::Integer,
    min_level::Integer,
    max_level::Integer,
)
    if next_value > prev_value
        limited_value = min(prev_value + 1, max_level)
    elseif next_value < prev_value
        limited_value = max(prev_value - 1, min_level)
    else
        limited_value = next_value
    end

    return limited_value
end

"""
    $(TYPEDSIGNATURES)
"""
function async_qn_step!(qn::QN)
    entity_labels = entities(qn)
    entity = rand(entity_labels)
    (min_level, max_level) = extrema(get_domain(qn, entity))
    t = target_functions(qn)[entity]
    old_state = get_state(qn, entity)
    new_state = interpret(t, qn)
    new_state = isnan(new_state) ? min_level : new_state
    new_state = isinf(new_state) ? max_level : new_state
    limited_state = limit_change(old_state, floor(Int, new_state), min_level, max_level)
    set_state!(qn, entity, limited_state)
end

"""
    $(TYPEDSIGNATURES)
"""
function sync_qn_step!(qn::QN)
    throw(ErrorException("Synchronous step function not yet implemented"))
end

extract_state(model::QN) = model.state
extract_parameters(model::QN) = model.graph
reset_model!(model::QN, u, _) = model.state .= u

function SciMLBase.reinit!(
    ds::ArbitrarySteppable{<:AbstractVector{<:Real},<:QualitativeNetwork},
    u::AbstractVector{<:Real} = initial_state(ds);
    p = current_parameters(ds),
    t0 = 0, # t0 is not used but required for downstream.
)
    ds.reinit(ds.model, u, p)
    ds.t[] = 0
    return ds
end

"""
    $(TYPEDSIGNATURES)

Construct an asynchronous [`QualitativeNetwork`](@ref) system using the
[`async_qn_step!`](@ref) as a step function.
"""
function create_qn_system(qn::QN)
    step_fn = get_schedule(qn) == Asynchronous() ? async_qn_step! : sync_qn_step!

    return ArbitrarySteppable(
        qn,
        step_fn,
        extract_state,
        extract_parameters,
        reset_model!,
        isdeterministic = false,
    )
end

function bma_dict_to_qn(bma_model::JSONModel)
    bma_entities = Entity.(entities(bma_model))
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
        added = add_edge!(mg, from(r), to(r), type(r))
        if !added
            @warn """
            Encountered a duplicate relationship between entities (from: \
            #$(from(r)); to: #$(to(r))) while constructing \
            the QN.
            """
        end
    end

    entities_with_functions = [
        Entity(
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

    return QualitativeNetwork(entities_with_functions; schedule = Asynchronous)
end

"""
    $(SIGNATURES)

Classify all symbols in `ex` as activators or inhibitors.

## Examples


"""
function classify_activators_inhibitors(ex, activators = [], inhibitors = [])
    (activators, inhibitors) = @match ex begin
        :($e) && if e isa Symbol
        end => (union(activators, [e]), inhibitors)
        (:($e + $other) || :($other + $e)) && if e isa Symbol
        end => classify_activators_inhibitors(other, union(activators, [e]), inhibitors)
        :(-$e) && if e isa Symbol
        end => (activators, union(inhibitors, [e]))
        :($other - $e) && if e isa Symbol
        end => classify_activators_inhibitors(other, activators, union(inhibitors, [e]))
        :($fn($(args...))) =>
            let a_i_pairs =
                    classify_activators_inhibitors.(args, (activators,), (inhibitors,))
                (union(first.(a_i_pairs)...), union(last.(a_i_pairs)...))
            end
        _ => (activators, inhibitors)
    end

    return activators, inhibitors
end

function classify_activators_inhibitors(d::AbstractDict)
    return Dict(e => fn for (e, fn) in d)
end

function remove_ids_from_entities_in_target_fn(ex)
    # Main.@infiltrate
    @match ex begin
        ::Symbol => Symbol(first(rsplit(string(ex), "_"; limit = 2)))
        Expr(:call, op, children...) =>
            Expr(:call, op, remove_ids_from_entities_in_target_fn.(children)...)
        _ => ex
    end

    # postwalk.(
    #     x -> @capture(x, e_Symbol) ? :($(Symbol(first(split(string(e), "_"))))) : x,
    #     functions,
    # )
end

"""
    $(SIGNATURES)

Write QN to a dictionary to output as JSON.

Use `JSON.json(qn)` directly to convert to JSON.
"""
function qn_to_bma_dict(qn::QN{N,S,M}) where {N,S,C,G,L<:EntityIdName,M<:MetaGraph{C,G,L}}
    lower_upper = extrema.(get_domain(qn))
    # names_and_ids = rsplit.(string.(entities(qn)), ('_',); limit = 2)
    # id_to_name = Dict(parse(Int, id) .=> name for (name, id) in names_and_ids)
    # name_to_id = Dict(name .=> parse(Int, id) for (name, id) in names_and_ids)


    # fns = Dict(id_to_name[id] => fn for fn in target_functions(qn))
    ids = id.(entities(qn))
    entity_names = name.(entities(qn))
    functions = [target_functions(qn)[e] for e in entities(qn)]
    activator_inhibitor_pairs = classify_activators_inhibitors(functions)
    functions = remove_ids_from_entities_in_target_fn.(functions)
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
            "FromVariable" => tryparse(Int, last(split(string(src), '_'))),
            "ToVariable" => tryparse(Int, last(split(string(dst), '_'))),
            "Type" => let (activators, inhibitors) = activator_inhibitor_pairs[dst]
                if src in activators
                    "Activator"
                elseif src in inhibitors
                    "Inhibitor"
                else
                    error("Malformed edge")
                end
            end,
        ) for (i, (src, dst)) in enumerate(edge_labels(get_graph(qn)))
    ]
    output_dict =
        Dict("Model" => Dict("Variables" => variables, "Relationships" => relationships))

    return output_dict
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
#
# function bma_dict_to_qn(bma_dict::AbstractDict)
#     bma_dict = nested_dicts_keys_to_lowercase(bma_dict)
#     model = bma_dict["model"]
#     variables = model["variables"]
#     relationships = model["relationships"]
#
#     id_to_name = Dict([v["id"] => v["name"] for v in variables])
#     names = [Symbol("$(v["name"])_$(v["id"])") for v in variables]
#     mg = MetaGraph(SimpleDiGraph(), Int, Union{Expr,Integer,Symbol}, String)
#
#     foreach(variables) do v
#         id = v["id"]
#         name = v["name"]
#         # adding an empty expression: :()
#         # because we need to construct the interaction graph
#         # first before parsing the functions correctly
#         added = add_vertex!(mg, id, :())
#         if !added
#             error(
#                 """
#                 Failed to add the entity (\"$name\", id: #$id) from the input file while \
#                 constructing the QN. Check that there is only one entity in the model with \
#                 the id #$id.
#                 """,
#             )
#         end
#     end
#
#     foreach(relationships) do r
#         from = to_from_variable_id(r, "from")
#         to = to_from_variable_id(r, "to")
#         type_of_edge = r["type"]
#         added = add_edge!(mg, from, to, type_of_edge)
#         if !added
#             @warn """
#             Encountered a duplicate relationship between entities (from: \
#             $(id_to_name[from]), #$from; to: $(id_to_name[to]), #$to) while constructing \
#             the QN.
#             """
#         end
#     end
#
#     formulas = Union{Expr,Integer,Symbol}[
#         create_target_function(v, collect(inneighbor_labels(mg, v["id"])), id_to_name, mg) for v in variables
#     ]
#
#     domains = [v["rangefrom"]:v["rangeto"] for v in variables]
#
#     return QualitativeNetwork(names, formulas, domains; schedule = Asynchronous)
# end
#
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
    variable::Entity{EntityIdName{S},Int},
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
            @warn "$(name(variable)) has no inputs, defaulting formula to lowest value ($(range_from(variable)))."
            return range_from(variable)
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
#
# function to_from_variable_id(r, from_to)
#     k = "$(from_to)variable"
#     k_w_id = k * "id"
#
#     if haskey(r, k)
#         return r[k]
#     elseif haskey(r, k_w_id)
#         return r[k_w_id]
#     else
#         error("""
#               Neither alternative key was found to retrieve the edge variable id. The \
#               model file is not using the expected structure for BMA models.
#               """)
#     end
# end
