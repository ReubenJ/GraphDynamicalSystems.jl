@testitem "Code quality (Aqua.jl)" begin
    using Aqua
    Aqua.test_all(GraphDynamicalSystems)
end

@testitem "Code quality (JET.jl)" begin
    using JET
    if VERSION ≥ v"1.12"
        JET.test_package(GraphDynamicalSystems; target_modules = (GraphDynamicalSystems,))
    end
end

@testitem "Explicit imports" begin
    using ExplicitImports: test_explicit_imports
    test_explicit_imports(GraphDynamicalSystems)
end
