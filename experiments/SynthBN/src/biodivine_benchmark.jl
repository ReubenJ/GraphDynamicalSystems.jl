using CondaPkg
using Git

using DataFrames, CSV

import GraphDynamicalSystems.BooleanNetworks: update_functions_to_network
using MetaGraphsNext: MetaGraph
using Graphs: SimpleDiGraph, add_edge!
using SoleLogics: Atom, subformulas, Formula

using Term: Progress, ProgressBar

using TidierData

function get_biodivine_repo(raw_src_dir)
    remote = "https://github.com/ReubenJ/biodivine-boolean-models.git"
    commit_hash = "f785e571308122378664d0ad4168969cb70cdcc2"
    checkout_cmd = `$(git()) checkout $commit_hash`

    if ispath(raw_src_dir)
        cd(raw_src_dir)
        try
            run(`$(git()) pull`)
            run(checkout_cmd)
        catch
            @error "Error pulling from git remote, see git output above."
        end
    else
        run(`$(git()) clone $remote $raw_src_dir`)
        cd(raw_src_dir)
        run(checkout_cmd)
    end
end

function bundle_biodivine_benchmark(raw_src_dir, output_dir)
    cd(raw_src_dir)
    CondaPkg.withenv() do
        run(
            `python bundle.py --format aeon --inputs free --filter "" --output-dir $output_dir`,
        )
    end
end

function load_aeon_biodivine()
    repo = datadir("src_raw", "biodivine-boolean-models")

    if !ispath(repo)
        include("fetch_repo.jl")
        @assert ispath(repo)
    end

    models_path = joinpath(repo, "bbm-aeon-format")
    summary_csv_path = joinpath(models_path, "summary.csv")
    df = DataFrame(CSV.File(summary_csv_path; types = Dict([:ID => String])))
    df[!, :path] = [joinpath(models_path, id) * ".aeon" for id in df.ID]
    @tagsave(datadir("src_parsed", "summary_biodivine_benchmark.jld2"), @strdict(df))

    pbar = ProgressBar(; columns = :detailed)
    Progress.foreachprogress(
        df.path,
        pbar;
        parallel = true,
        transient = false,
        description = "Loading models...",
    ) do model
        if basename(model) != "079.aeon" # 79 is massive and seems to cause a stackoverflow error
            @produce_or_load(
                @dict(model), # produce_or_load needs this to be a dict
                path = datadir("src_parsed", "biodivine_benchmark"),
                filename = basename(model),
            ) do config
                @unpack model = config
                parsed_model = AEONParser.parse_aeon_file(model, pbar)
                @strdict parsed_model
            end
        end
    end
end

function update_functions_to_network(
    update_functions::AbstractVector{<:AEONParser.UpdateFunction},
    regulations::AbstractVector{<:AEONParser.Regulation},
)
    network = MetaGraph(SimpleDiGraph(); label_type = Atom, vertex_data_type = Formula)

    # By default let every node's update function equal itself
    # This means applying an update won't do anything
    for reg in regulations
        network[Atom(reg.regulator.name)] = Atom(reg.regulator.name)
        network[Atom(reg.target.name)] = Atom(reg.target.name)
    end

    network[Atom("v_External_Activator")] = Atom("v_External_Activator")

    # Then for any node that does have an update function, we assign it here
    for up in update_functions
        network[Atom(String(up.target.name))] = up.fn
    end

    for up in update_functions
        atoms = Set(Leaves(up.fn))
        for atom in atoms
            source = atom.value
            add_edge!(network, up.target.name, source)
        end
    end

    return network
end

function convert_aeon_models_to_metagraphs()
    excluded_files = [r"041\.aeon\.jld2", r"079\.aeon\.jld2"]

    df = collect_results!(
        datadir("src_parsed", "biodivine_benchmark");
        rexclude = excluded_files,
    )
    # "full/path/to/001.aeon.jld2" -> "001"
    df.ID = map((x -> x[1]) ∘ splitext ∘ (x -> x[1]) ∘ splitext ∘ basename, df.path)

    components_df = @chain df begin
        @select parsed_model ID
        flatten(:parsed_model)
        # Twice because I've accidentally added each component as a vector of length 1
        flatten(:parsed_model)
        @rename Component = parsed_model  # new = old
        @mutate ComponentType = typeof(Component)
        @group_by ComponentType
    end

    just_update_functions = components_df[(ComponentType = AEONParser.UpdateFunction,)]
    just_regulations = components_df[(ComponentType = AEONParser.Regulation,)]

    update_functions_by_id = @chain just_update_functions begin
        @group_by ID
        @select Component
    end

    regulations_by_id = @chain just_regulations begin
        @group_by ID
        @select Component
    end

    pbar = ProgressBar(; columns = :detailed)
    Progress.foreachprogress(
        collect(zip(update_functions_by_id, regulations_by_id)),
        pbar;
        parallel = true,
        transient = false,
        # description = "AEON -> MetaGraph",
    ) do model
        @produce_or_load(
            @dict(model), # produce_or_load needs this to be a dict
            path = datadir("src_parsed", "biodivine_benchmark_as_metagraphs"),
            filename = model[1].ID[1],
        ) do config
            @unpack model = config
            (update_functions, regulations) = model
            metagraph_model = update_functions_to_network(
                Vector{AEONParser.UpdateFunction}(update_functions.Component),
                Vector{AEONParser.Regulation}(regulations.Component),
            )
            @strdict metagraph_model
        end
    end
end
