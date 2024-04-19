module CedarEDA

using PrecompileTools, Reexport
import TOML

# This does not seem to be that effective, check out `@time_imports using CedarEDA`.
#@recompile_invalidations begin
    # Import our LinkProvider (need a way to ensure that the listener is installed!)
    export run_callback
    include("LinkProvider.jl")
    using .LinkProvider

    include("Logging.jl")

    # Some simple adapters to make the transition between CedarWaves versions easier
    include("ProbeSelector.jl")
    include("CedarWavesCompat.jl")

    
    # Import our SimManager API (and its checks and measures and whatnot)
    @reexport using CedarSim, CedarWaves
    const SIFactors = CedarWaves.SIFactors
    include("SimManager/SimManager.jl")


    include("measure_sensitivity.jl")
    include("optimization.jl")
    include("extra_rules.jl")

    # Import our plotting extensions
    using WGLMakie
    include("SimManager/Plotting.jl")

#end

# This value is baked at precompile time, which allows the version to exist even when compiled as part of the systemimage.
const cedareda_version = pkgversion(CedarEDA)

# We use RelocatableFolders.jl to digest the examples directory when precompiling
# to make sure that the content is available in the pkgimage/sysimage.
import RelocatableFolders
const EXAMPLES = RelocatableFolders.@path joinpath(@__DIR__, "..", "examples") ignore=r"\.csv$"

# Examples are installed in __init__ as a read-only directory within the user's JuliaHub
# directory. The examples are versioned according to CedarEDA's version number. If there is
# a version mismatch we replace the folder.
function install_examples()
    dst = expanduser("~/data/code/examples (read-only)")
    mkpath(dst)
    # Check installed version
    installed_version = nothing
    version_toml = joinpath(dst, "Version.toml")
    if isfile(version_toml)
        installed_version = get(TOML.parsefile(version_toml), "version", nothing)
    end
    # If the versions match, leave the examples alone
    installed_version == string(cedareda_version) && return
    # Make directories writable to be allowed to delete
    chmod(dst, filemode(dst) | 0o222)
    for (root, dirs, _) in walkdir(dst), dir in dirs
        fullpath = joinpath(root, dir)
        chmod(fullpath, filemode(fullpath) | 0o222)
    end
    # Force copy fully replaces dst
    cp(CedarEDA.EXAMPLES, dst; force = true)
    open(version_toml, "w") do io
        TOML.print(io, Dict("version" => string(cedareda_version)))
    end
    return
end

function __init__()
    # Force WGLMakie to resize to body, which gets automatic resizing in VSCode
    try
        WGLMakie.activate!(;resize_to=:body)
    catch
    end

    # Tell JSServe/Bonito that it should keep plots around for 10 hours
    if isdefined(WGLMakie, :JSServe)
        WGLMakie.JSServe.set_cleanup_time!(10.0)
    elseif isdefined(WGLMakie, :Bonito)
        WGLMakie.Bonito.set_cleanup_time!(10.0)
    end

    # Install examples if running on JuliaHub.
    if haskey(ENV, "JULIAHUB_PRODUCT_NAME")
        install_examples()
    end

    # Initialize logging to a default state
    configure_logging!()
end

end # module CedarEDA
