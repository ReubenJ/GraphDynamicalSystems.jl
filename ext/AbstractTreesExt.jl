module AbstractTreesExt
import AbstractTrees as AT
import GraphDynamicalSystems as GDS

function GDS.Constructors.vertex_function_to_edgelist(vertex, fn, all_vertices)
    recurse_if = x -> !(x in all_vertices)
    return filter(in(all_vertices), collect(AT.PreOrderDFS(recurse_if, fn))) .=> (vertex,)
end
end
