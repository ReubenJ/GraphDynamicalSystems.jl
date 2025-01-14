using CondaPkg
using Git

using DataFrames, CSV

import GraphDynamicalSystems.BooleanNetworks: update_functions_to_network
using MetaGraphsNext: MetaGraph
using Graphs: SimpleDiGraph, add_edge!
using SoleLogics: Atom, subformulas, Formula

# using Term
using ProgressMeter

using TidierData

using Distributed

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

function load_aeon_biodivine(repo, ids_to_ignore = String[])
    @assert ispath(repo)

    models_path = joinpath(repo, "bbm-aeon-format")
    summary_csv_path = joinpath(models_path, "summary.csv")

    df = DataFrame(
        CSV.File(summary_csv_path; types = Dict([:ID => String]), normalizenames = true),
    )

    # construct path column
    df = transform(df, :ID => ByRow(id -> joinpath(models_path, id) * ".aeon") => :path)

    @tagsave(datadir("src_parsed", "summary_biodivine_benchmark.jld2"), @strdict(df))

    df = filter(row -> row.ID ∉ ids_to_ignore, df)

    @showprogress "Parsing AEON Files..." pmap(eachrow(df)) do model
        @produce_or_load(
            model,
            path = datadir("src_parsed", "biodivine_benchmark"),
            filename = basename(model.path),
            verbose = false
        ) do model
            parsed_model = AEONParser.parse_aeon_file(model.path)
            @strdict parsed_model
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
    # Should've chosen `identity` for inputs when bundling the benchmark
    for reg in regulations
        network[Atom(reg.regulator.name)] = Atom(reg.regulator.name)
        network[Atom(reg.target.name)] = Atom(reg.target.name)
    end

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

function convert_aeon_models_to_metagraphs(excluded_files = Regex[])
    df = collect_results(
        datadir("src_parsed", "biodivine_benchmark");
        rexclude = excluded_files,
    )
    # "full/path/to/001.aeon.jld2" -> "001"
    df.ID = map((x -> x[1]) ∘ splitext ∘ (x -> x[1]) ∘ splitext ∘ basename, df.path)

    gdf = @chain df begin
        @select parsed_model ID
        flatten(:parsed_model)
        @rename Component = parsed_model  # new = old
        @mutate ComponentType = typeof(Component)
        @group_by ID
    end

    @showprogress "AEON -> MetaGraph" pmap(pairs(gdf)) do (components_key, components)
        @produce_or_load(
            components,
            path = datadir("src_parsed", "biodivine_benchmark_as_metagraphs"),
            filename = components_key.ID
        ) do components
            metagraph_model = update_functions_to_network(
                Vector{AEONParser.UpdateFunction}(
                    components[
                        components.ComponentType.==AEONParser.UpdateFunction,
                        :,
                    ].Component,
                ),
                Vector{AEONParser.Regulation}(
                    components[
                        components.ComponentType.==AEONParser.Regulation,
                        :,
                    ].Component,
                ),
            )
            @strdict metagraph_model
        end
    end
end
