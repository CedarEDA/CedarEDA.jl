production_examples_dir = joinpath(dirname(@__DIR__), "examples")
test_examples_dir = joinpath(@__DIR__, "examples")

function find_examples(root)
    examples = String[]
    # We define an example as a julia script that is in the same directory as a `README.md` file.
    for (root, dirs, files) in walkdir(root)
        if !("README.md" ∈ files)
            continue
        end

        for julia_script in filter(endswith(".jl"), files)
            push!(examples, joinpath(root, julia_script))
        end
    end
    return examples
end


