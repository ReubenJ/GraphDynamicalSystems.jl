@testitem "Code quality (Aqua.jl)" begin
    using Aqua
    Aqua.test_all(GraphDynamicalSystems)
end

@testitem "Code linting (JET.jl)" begin
    using JET
    JET.test_package(GraphDynamicalSystems; target_defined_modules = true)
end
