using DrWatson

@quickactivate

using DataFrames, CSV, ProgressBars

include(srcdir("parse_aeon.jl"))

repo = datadir("src_raw", "biodivine-boolean-models")

if !ispath(repo)
    include("fetch_repo.jl")
    @assert ispath(repo)
end

struct BiodivineBooleanNetwork{D<:AbstractDict}
    model::Any
    metadata::D
end

models_path = joinpath(repo, "bbm-aeon-format")
summary_csv_path = joinpath(models_path, "summary.csv")
summary_df = DataFrame(CSV.File(summary_csv_path; types = Dict([:ID => String])))
summary_df[!, :path] = [joinpath(models_path, id) * ".aeon" for id in summary_df.ID]


iter = ProgressBar(summary_df.path)
res = []
for model in iter
    @show model, filesize(model)
    push!(res, parse_aeon_file(model))
end

summary_df[!, :model] = res

@tagsave(datadir("src_raw", "parsed_biodivine_benchmarks.jld2"), @strdict(summary_df))
