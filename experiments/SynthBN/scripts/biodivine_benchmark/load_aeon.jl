using DrWatson

@quickactivate :SynthBN

using DataFrames, CSV, ProgressBars

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


    iter = ProgressBar(df.path)
    res = []
    for model in iter
        @show model, filesize(model)
        push!(res, AEONParser.parse_aeon_file(model))
    end

    df[!, :model] = res

    @tagsave(datadir("src_raw", "parsed_biodivine_benchmarks.jld2"), @strdict(df))
end

load_aeon()
