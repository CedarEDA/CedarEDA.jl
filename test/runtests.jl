using Test, CedarEDA

# when testing, don't use WGLMakie, use CairoMakie
using CairoMakie
CairoMakie.activate!()

include("SimManager.jl")

@testset "Example installation in __init__" begin
    home = mktempdir()
    cmd = addenv(
        `$(Base.julia_cmd()) --project=$(Base.active_project()) -e 'using CedarEDA'`,
        "HOME" => home,
        # Need to preserve the DEPOT_PATH since it depends on HOME
        "JULIA_DEPOT_PATH" => join(DEPOT_PATH, ":"),
        "JULIAHUB_PRODUCT_NAME" => "CedarEDA",
    )
    user_example_dir = joinpath(home, "data/code/examples (read-only)")
    example_file = joinpath(user_example_dir, "Filter/Butterworth/butterworth_transient.jl")
    # No files to begin with
    @test !isfile(example_file)
    # Run command once
    @test success(cmd)
    @test isfile(example_file)
end

include("Surrogates/surrogate_test.jl")

include("example_checks.jl")
