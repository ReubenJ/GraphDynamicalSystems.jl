module SynthBN

using DrWatson

@quickactivate "SynthBN"

include(srcdir("parse_aeon.jl"))

export AEONParser

end
