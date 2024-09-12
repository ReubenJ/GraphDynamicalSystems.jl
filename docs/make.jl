using GraphDynamicalSystems
using Documenter

DocMeta.setdocmeta!(
    GraphDynamicalSystems,
    :DocTestSetup,
    :(using GraphDynamicalSystems);
    recursive = true,
)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [GraphDynamicalSystems],
    authors = "Reuben Gardos Reid <5456207+ReubenJ@users.noreply.github.com>",
    repo = "https://github.com/ReubenJ/GraphDynamicalSystems.jl/blob/{commit}{path}#{line}",
    sitename = "GraphDynamicalSystems.jl",
    format = Documenter.HTML(;
        canonical = "https://ReubenJ.github.io/GraphDynamicalSystems.jl",
    ),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/ReubenJ/GraphDynamicalSystems.jl")
