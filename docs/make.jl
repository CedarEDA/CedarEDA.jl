# Insert `CedarEDA` into our load path so we use its manifest for all the `CedarEDA` deps
if !(dirname(@__DIR__) ∈ Base.LOAD_PATH)
    insert!(Base.LOAD_PATH, 2, dirname(@__DIR__))
end

@info("Loading CedarEDA... (please speed this up, Jameson!)")
using Documenter, Base64, CedarEDA, CedarSim, CedarWaves, BetterFileWatching

# Normalize the documenter key if it's not already base64-encoded
documenter_key = get(ENV, "DOCUMENTER_KEY", "")
try
    base64decode(documenter_key)
catch e
    if isa(e, ArgumentError)
        if !endswith(documenter_key, "\n")
            global documenter_key = string(documenter_key, "\n")
        end
        ENV["DOCUMENTER_KEY"] = base64encode(documenter_key)
    else
        rethrow(e)
    end
end

function do_doc_build(; warnonly = [:missing_docs])
    # Ensure that our examples have been translated into markdown.
    # Also defines the `examples_reference` variable.
    include("translate_examples.jl")

    @info("Running any `0_setup.jl` files in the `src/` tree...")
    # Ensure that we've run any `0_setup.jl` files.
    # We run them in parallel for maximum efficiency.
    function find_setup_files(root)
        setup_files = String[]
        for (root, dirs, files) in walkdir(root)
            if "0_setup.jl" ∈ files
                push!(setup_files, joinpath(root, "0_setup.jl"))
            end
        end
        return setup_files
    end
    Threads.@threads for setup_file in find_setup_files(joinpath(@__DIR__, "src/"))
        run(Cmd(`$(Base.julia_cmd()) --project=$(Base.active_project()) $(setup_file)`; dir=dirname(setup_file)))
    end

    makedocs(;
        sitename = "CedarEDA",
        authors="JuliaHub, Inc.",
        format=Documenter.HTML(;
            edit_link=nothing,
            sidebar_sitename=false,
            ansicolor=true,
            repolink=nothing,
            assets=["assets/custom.css"],
            # Only create pretty URLs when we're on CI, for local builds don't.
            prettyurls = get(ENV, "CI", "false") == "true",
        ),
        modules = [CedarEDA, CedarSim],
        remotes = nothing,
        clean = true,
        warnonly,
        # Do not generate links to jump to the source, since it is not opensource yet.
        pages = [
            "Home" => "index.md",
            "Getting Started" => [
                "Launching CedarEDA on JuliaHub" => "gettingstarted/JuliaHub.md",
                "Running Transient Analysis" => "gettingstarted/RunningTran.md",
                "Running Parametric Sweeps" => "gettingstarted/ParametricSweeps.md",
                "Running DC Analysis" => "gettingstarted/RunningDC.md",
                "Running AC Analysis" => "gettingstarted/RunningAC.md",
                "Working with Plots" => "gettingstarted/WorkingWithPlots.md",
                "Parameter Tuning with Optimization" => "gettingstarted/ParameterTuning.md",
            ],
            "User Guide" => [
                "Simulation Basics" => "user_guide/simulation_basics.md",
                "Syntax Support" => [
                    "SPICE Syntax" => "user_guide/syntax_support/spice_syntax.md",
                    "Spectre Syntax" => "user_guide/syntax_support/spectre_syntax.md",
                    "Verilog-A Syntax" => "user_guide/syntax_support/veriloga_syntax.md",
                ],
                "Importing Netlists" => [
                    "Import from KiCAD" => "user_guide/importing/kicad.md",
                    "Import from xschem" => "user_guide/importing/xschem.md",
                ],
                "Reporting Issues" => "user_guide/reporting_issues.md",
            ],
            "Reference" => [
                "Examples Reference" => examples_reference,
                "API Reference" => "reference/api_reference.md",
            ],
        ]
    )
    @info("Copying `build` -> `deploy`")
    # Copy to `deploy`, so that when doing intermediate looping builds,
    # we don't lose the ability to look at things while it's building
    rm(joinpath(@__DIR__, "deploy"); recursive=true, force=true)
    cp(joinpath(@__DIR__, "build"), joinpath(@__DIR__, "deploy"))
    println()
end

function try_doc_build()
    try
        do_doc_build(; warnonly=true)
    catch e
        display(e)
    end
end

build_dir = abspath(mkpath(joinpath(@__DIR__, "build")))
deploy_dir = abspath(mkpath(joinpath(@__DIR__, "deploy")))
function is_interesting_path(f)
    # Reject `.DS_Store` file modifications from clicking around in the Finder.
    if basename(f) == ".DS_Store"
        return false
    end

    # Reject paths that are within `build/` or `deploy/`
    if startswith(abspath(f), build_dir) || startswith(abspath(f), deploy_dir)
        return false
    end

    return true
end

# Pass `--loop` when you're working iteratively on these things
# This helps a lot when the big cost you pay is just `using CedarEDA` :(
if "--loop" in ARGS
    try_doc_build()
    last_build = time()
    watch_folder(dirname(@__DIR__)) do f
        # Skip changes to things like `.DS_Store`, which shouldn't re-trigger us.
        if !any(is_interesting_path.(f.paths))
            return
        end

        global last_build
        # Throttle updates a bit, to prevent multiple queued builds
        # from stampeding
        if time() - last_build < 0.1
            return
        end
        try_doc_build()
        last_build = time()
    end
else
    do_doc_build()
    deploydocs(
        repo = "github.com/JuliaComputing/CedarEDA.jl.git",
        branch = "docs",
        target = "build",
    )
end
