# Load every example, and just run `check()` on the defined top-level values:
using Test
using CedarEDA

include("example_utils.jl")

for example_dir in [production_examples_dir, test_examples_dir]
    for example_file in find_examples(example_dir)
        example_name = relpath(example_file, example_dir)
        @testset "$(example_name)" begin
            # This is to create section headings when we're running under buildkite
            if get(ENV, "BUILDKITE", "false") == "true"
                println("\n--- Example: $(example_name)")
            end
            mod = Module()
            Core.include(mod, example_file)

            # Run `check()` and ensure that the result has at least one row where
            # all checks are successful.  Some of our examples name our `sp` as
            # different names, so we just search for any/all of them.
            for sp_name in (:sp, :tran_sp, :ac_sp)
                if hasproperty(mod, sp_name)
                    sp = getproperty(mod, sp_name)
                    df = check(sp)
                    if !isempty(df)
                        @test any(is_success.(eachrow(df)))
                    end
                    # Test that a successful solver was saved
                    @test sp.successful_solver[] isa Symbol
                end
            end
        end
    end
end
