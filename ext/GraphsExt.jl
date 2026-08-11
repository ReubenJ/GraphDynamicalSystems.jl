module GraphsExt
import Graphs
import GraphDynamicalSystems as GDS

GDS.vertices(graph::Graphs.AbstractGraph) = Graphs.vertices(graph)
GDS.edges(graph::Graphs.AbstractGraph) = Graphs.edges(graph)

function GDS.Conversions.to_simple_graph(gds)
    v = GDS.vertices(gds)
    e = [Graphs.Edge(findfirst(==(s), v), findfirst(==(d), v)) for (s, d) in GDS.edges(gds)]
    return Graphs.SimpleDiGraph(e)
end
end
