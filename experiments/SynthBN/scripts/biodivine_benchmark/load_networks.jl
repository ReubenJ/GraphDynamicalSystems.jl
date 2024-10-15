using DrWatson

@quickactivate

using DataFrames, CSV, JSON, XML, ProgressBars, SBML

repo = datadir("src_raw", "biodivine-boolean-models")

if !ispath(repo)
    include("fetch_repo.jl")
    @assert ispath(repo)
end

struct BiodivineBooleanNetwork{D<:AbstractDict}
    model::Any
    metadata::D
end

function remove_attribute!(node::XML.Node, attribute::AbstractString)
    if !isnothing(node.attributes)
        delete!(node.attributes, attribute)
    end

    [remove_attribute!(child, attribute) for child in XML.children(node)]
    return node
end

models_path = joinpath(repo, "models")
summary_csv_path = joinpath(models_path, "summary.csv")
summary_csv = DataFrame(CSV.File(summary_csv_path))

models::Vector{BiodivineBooleanNetwork} = []

iter = ProgressBar(filter(isdir, readdir(models_path, join = true)))

for model in iter
    # @show basename(model)
    metadata_path = joinpath(model, "metadata.json")
    metadata = JSON.parsefile(metadata_path)
    sbml_path = joinpath(model, "model.sbml")
    if filesize(sbml_path) < 1_000_000
        sbml_doc = XML.read(sbml_path, XML.Node)
        remove_attribute!(sbml_doc, "essential")
        sbml = SBML.readSBMLFromString(XML.write(sbml_doc))
        push!(models, BiodivineBooleanNetwork(sbml_doc, metadata))
    else
        println(iter, "Skipping $(basename(model)) due to large XML size")
    end

end
