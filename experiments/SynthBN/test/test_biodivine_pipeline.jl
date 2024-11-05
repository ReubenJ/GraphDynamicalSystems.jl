@testset "Biodivine Pipeline" begin
    @testset "AEON Parsing" begin
        ex_model_file = testdir("007.aeon")
        parsed_model = AEONParser.parse_aeon_file(ex_model_file)

        @test length(filter(x -> x isa AEONParser.UpdateFunction, parsed_model)) == 5
        @test length(filter(x -> x isa AEONParser.Regulation, parsed_model)) == 14
    end
end
