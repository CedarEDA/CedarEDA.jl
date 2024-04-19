using DescriptorSystems: dss
using CedarSim: NoiseSol, PSD

const NoiseSolutionType = SolutionSet{Val{:Noise}}


function NoiseSolution!(as::SolutionSet, noises::AbstractArray{<:NoiseSol}, sols::AbstractArray{<:SciMLBase.AbstractODESolution}, ωs::Vector{Float64})
    prob = first(sols).prob
    as.outputs[:noise] = TabCompleter(
        "Frequency Response",
        get_transformed_sys(prob).state.sys;
        leaf = (k, ref) -> get_noise(as, ref),
        keys = x -> isempty(propertynames(x)) ? nothing : propertynames(x),
        getindex = getproperty,
    )
    as.shaped_metadata[:noises] = noises
    as.shaped_metadata[:sols] = sols
    as.unshaped_metadata[:ωs] = ωs
    as.reconstruction_caches[:noise] = Dict{ScopeRef,Array{Vector{ComplexF64},ndims(sols)}}()
end

function NoiseSolution(noises::AbstractArray{<:NoiseSol}, ωs::Vector{Float64})
    sols = [noise.sol for noise in noises]
    sol_checks(sols)

    as = SolutionSet(:Noise, size(sols))
    Parameters!(as, sols)
    DCSolution!(as, sols)
    NoiseSolution!(as, noises, sols, ωs)
    return as
end

# This function doesn't really build a reconstruction function, it just ensures
# that the reconstruction function we're interested in is compiled.
function build_noise_reconstruct(ss, uncached_refs)
    [first(getfield(ss, :shaped_metadata)[:noises])[ref] for ref in uncached_refs]
    return nothing
end

function cache_noise!(ss::SolutionSet, refs::Vector{<:ScopeRef})
    ωs = getfield(ss, :unshaped_metadata)[:ωs]
    return cache!(ss, :noise, refs, build_noise_reconstruct) do metadata, uncached_refs, _
        return [PSD(metadata[:noises], ref, ωs) for ref in uncached_refs]
    end
end
cache_noise!(ss::SolutionSet, ref::ScopeRef) = cache_noise!(ss, [ref])

function get_noise(ss::SolutionSet, probe::Union{ScopeRef,Probe}, idxs = [Colon() for _ in 1:ndims(ss)])
    ωs = getfield(ss, :unshaped_metadata)[:ωs]
    freq_vecs = only(cache_noise!(ss, ScopeRef(ss, probe)))

    # Convert reconstructed values to signals.  We know that for a single probe
    # there is a single timeseries, so we just index the first one:
    function signal_ctor(idx)
        u = freq_vecs[idx]
        return Signal(ωs, u)
    end
    return signal_ctor.(CartesianIndices(freq_vecs)[idxs...])
end
