using DrWatson

@quickactivate :SynthBN

using DataFrames, CSV

using Term: Progress, ProgressBar

function load_aeon()
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

load_aeon()
