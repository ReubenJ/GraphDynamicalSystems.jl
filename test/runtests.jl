using Aqua
using GraphDynamicalSystems
using JET
using Test


#=
Don't add your tests to runtests.jl. Instead, create files named

    test-title-for-my-test.jl

The file will be automatically included inside a `@testset` with title "Title For My Test".
=#
@testset "GraphDynamicalSystems.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(GraphDynamicalSystems)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(GraphDynamicalSystems; target_defined_modules = true)
    end

    for (root, dirs, files) in walkdir(@__DIR__)
        for file in files
            if isnothing(match(r"^test-.*\.jl$", file))
                continue
            end
            title = titlecase(replace(splitext(file[6:end])[1], "-" => " "))
            @testset "$title" begin
                include(file)
            end
        end
    end
end
