using ReTestItems: runtests, @testitem
import GraphDynamicalSystems, BooleanNetworks, QualitativeNetworks

runtests(BooleanNetworks)
runtests(QualitativeNetworks)
runtests(GraphDynamicalSystems)
