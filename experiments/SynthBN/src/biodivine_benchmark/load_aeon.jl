using DataFrames, CSV

import GraphDynamicalSystems.BooleanNetworks: update_functions_to_network
using MetaGraphsNext: MetaGraph
using Graphs: SimpleDiGraph
using SoleLogics: Atom, subformulas, Formula

using Term: Progress, ProgressBar

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

    pbar = ProgressBar()
    Progress.foreachprogress(
        df.path,
        pbar;
        parallel = true,
        transient = true,
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
)
    network = MetaGraph(SimpleDiGraph(); label_type = String, vertex_data_type = Formula)

    for up in update_functions
        network[up.target.name] = up.fn
    end

    for up in update_functions
        atoms = filter(x -> isa(x, Atom), subformulas(up.fn))
        for atom in atoms
            source = atom.value
            add_edge!(network, up.target.name, source)
        end
    end

    return network
end
