#
# `include("test/quick.jl")` for quick testing
#
# Assumes you have TestEnv and ReTestItems installed in your
# global Julia environment.
#
using TestEnv
using ReTestItems
using GraphDynamicalSystems

TestEnv.activate()
rt() = runtests(GraphDynamicalSystems, failfast = true, failures_first = true)
