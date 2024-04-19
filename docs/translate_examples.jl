include("../test/example_utils.jl")

@info("Copying examples and translating to markdown...")
target_dir = joinpath(@__DIR__, "src/examples")
rm(target_dir; force=true, recursive=true)

# Find the directories of all examples
example_dirs = Set{String}()
for example_file in find_examples(production_examples_dir)
    push!(example_dirs, dirname(example_file))
end

function wrap_in_markdown(path)
    content = String(read(path))
    md_path = string(path, ".md")
    if ispath(md_path)
        throw(ArgumentError("Cannot translate $path: markdown file already exists!"))
    end
    open(md_path; write=true) do io
        println(io, page_title(path))

        println(io, "Below shows the contents of: `$(basename(path))`")
        println(io, "```julia")
        print(io, content)
        println(io, "```")
    end
    # Set it as read-only to prevent human error when trying to edit these in VSCode
    fmode = filemode(md_path)
    chmod(md_path, fmode & (typemax(fmode) ⊻ 0o222))
    return md_path
end

function page_title(path)
    bname = basename(path)
    fname, ext = splitext(bname)
    name = replace(fname, "_" => " ")
    type = if ext == ".jl"
        "julia script"
    elseif ext ∈ (".sp", ".spice")
        "spice netlist"
    else
        ext * " file"
    end
    return "### [$name $type](@id $bname)"
end

# Copy all of our examples into `docs`
examples_reference = []
for example_dir in example_dirs
    rel = relpath(example_dir, production_examples_dir)
    dest_dir = joinpath(target_dir, rel)
    mkpath(dirname(dest_dir))
    cp(example_dir, dest_dir)

    # Once copied, find all `.jl` files and convert them to `.md` files
    for path in readdir(dest_dir; join=true)
        if endswith(path, ".jl")
            md_path = wrap_in_markdown(path)
            rm(path)
        elseif endswith(path, ".spice") || endswith(path, ".sp")
            wrap_in_markdown(path)
            rm(path)
        elseif basename(path) == "README.md"
            # Scan the `README.md` file for links to `.jl` files, convert them to `.md` files:
            md_content = String(read(path))
            md_content = replace(md_content, r"\]\(([^)]+\.jl)\)" => s"](\1.md)")
            md_content = replace(md_content, r"\]\(([^)]+\.spice)\)" => s"](\1.md)")
            md_content = replace(md_content, r"\]\(([^)]+\.sp)\)" => s"](\1.md)")

            # Find LaTeX sections marked with `$$` and convert them to ```math``` sections.
            md_content = replace(md_content, r"\$\$([^\$]+)\$\$" => s"```math\n\1\n```")
            open(path; write=true) do io
                print(io, md_content)
            end
        end
    end

    # Build path in `examples_reference` to our page
    parent_path = String[]
    parent_rel = dirname(rel)
    while dirname(parent_rel) != ""
        push!(parent_path, basename(parent_rel))
        parent_rel = dirname(parent_rel)
    end
    push!(parent_path, basename(parent_rel))
    reverse!(parent_path)

    function findcategory(list, category)
        for (idx, item) in enumerate(list)
            if isa(item, Pair)
                if first(item) == category
                    return idx
                end
            end
        end
        return nothing
    end

    examples_ref_level = examples_reference
    for category in parent_path
        cat_idx = findcategory(examples_reference, category)
        if cat_idx === nothing
            push!(examples_ref_level, category => [])
            cat_idx = length(examples_ref_level)
        end
        examples_ref_level = examples_ref_level[cat_idx][2]
    end
    push!(examples_ref_level, basename(example_dir) => joinpath("examples", rel, "README.md"))
end
