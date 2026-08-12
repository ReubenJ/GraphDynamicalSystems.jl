module Constructors
using Compat: @compat

@compat public vertex_function_to_edgelist

"""
    vertex_function_to_edgelist(vertex_fn_pairs)
    vertex_function_to_edgelist(vertex, fn, all_vertices)

Create a list of edges based on the vertices that appear in `fn`.

If a vertex `X` has a function `X + Y` and `all_vertices = [X, Y, ...]`,
then return edges `X => X` and `X => Y`.

!!! note
    Requires `AbstractTrees` to be loaded.
"""
function vertex_function_to_edgelist(vertex_fn_pairs)
    return vcat(vertex_function_to_edgelist.(first.(vertex_fn_pairs), last.(vertex_fn_pairs), (first.(vertex_fn_pairs),))...)
end
# Second signature implemented in `AbstractTreesExt`

end
