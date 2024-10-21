module SynthBN

using DrWatson

include("biodivine_benchmark/parse_aeon.jl")
include("biodivine_benchmark/load_aeon.jl")
include("biodivine_benchmark/fetch_repo.jl")

export AEONParser,
    load_aeon_biodivine, fetch_biodivine_benchmark, bundle_biodivine_benchmark

end
