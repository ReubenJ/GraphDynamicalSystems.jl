using HerbSpecification
using DocStringExtensions

"""
    $(TYPEDEF)

Specification where it is not known whether f(data1) == data2 or f(data2) == data1.

$(TYPEDFIELDS)
"""
struct UndirectedExample
    "Either the input or output for this example."
    data1::Dict{Symbol,Any}
    "If data1 is the input, this field is the output, and vice-versa."
    data2::Dict{Symbol,Any}
end

"""
    $(TYPEDEF)

Problem defined over `UndirectedExample`s.

$(TYPEDFIELDS)
"""
struct UndirectedProblem
    name::AbstractString
    examples::AbstractVector{UndirectedExample}
end
