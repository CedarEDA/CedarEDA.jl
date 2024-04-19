using DescriptorSystems: dss, freqresp
using CedarSim: ACSol

const ACSolutionType = SolutionSet{Val{:AC}}


function ACSolution!(as::SolutionSet, acs::AbstractArray{<:ACSol}, sols::AbstractArray{<:SciMLBase.AbstractODESolution}, ωs::Vector{Float64})
    prob = first(sols).prob
    as.outputs[:ac] = TabCompleter(
        "Frequency Response",
        get_transformed_sys(prob).state.sys;
        leaf = (k, ref) -> get_ac(as, ref),
        keys = x -> isempty(propertynames(x)) ? nothing : propertynames(x),
        getindex = getproperty,
    )
    as.shaped_metadata[:acs] = acs
    as.shaped_metadata[:sols] = sols
    as.unshaped_metadata[:ωs] = ωs
    as.reconstruction_caches[:ac] = Dict{ScopeRef,Array{Vector{ComplexF64},ndims(sols)}}()
end

function ACSolution(acs::AbstractArray{<:ACSol}, ωs::Vector{Float64})
    sols = [ac.sol for ac in acs]
    sol_checks(sols)

    as = SolutionSet(:AC, size(sols))
    Parameters!(as, sols)
    DCSolution!(as, sols)
    ACSolution!(as, acs, sols, ωs)
    return as
end

# This function doesn't really build a reconstruction function, it just ensures
# that the reconstruction function we're interested in is compiled.
function build_ac_reconstruct(ss, uncached_refs)
    [first(getfield(ss, :shaped_metadata)[:acs])[ref] for ref in uncached_refs]
    return nothing
end

function cache_ac!(ss::SolutionSet, refs::Vector{<:ScopeRef})
    ωs = getfield(ss, :unshaped_metadata)[:ωs]
    return cache!(ss, :ac, refs, build_ac_reconstruct) do metadata, uncached_refs, _
        return [freqresp(metadata[:acs], ref, ωs) for ref in uncached_refs]
    end
end
cache_ac!(ss::SolutionSet, ref::ScopeRef) = cache_ac!(ss, [ref])

function get_ac(ss::SolutionSet, probe::Union{ScopeRef,Probe}, idxs = [Colon() for _ in 1:ndims(ss)])
    ωs = getfield(ss, :unshaped_metadata)[:ωs]
    freq_vecs = only(cache_ac!(ss, ScopeRef(ss, probe)))

    # Convert reconstructed values to signals.  We know that for a single probe
    # there is a single timeseries, so we just index the first one:
    function signal_ctor(idx)
        u = freq_vecs[idx]
        return Signal(ωs, u)
    end
    return signal_ctor.(CartesianIndices(freq_vecs)[idxs...])
end
