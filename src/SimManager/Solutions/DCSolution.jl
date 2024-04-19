using SciMLBase

const DCSolutionType = SolutionSet{Val{:DC}}

# Used to add a DC `.op` property to a solution set, based on the provided `sols`
function DCSolution!(ds::SolutionSet, sols::AbstractArray{<:AbstractODESolution})
    prob = first(sols).prob
    ds.outputs[:op] = TabCompleter(
        "DC Operating Point",
        get_transformed_sys(prob).state.sys;
        leaf = (k, ref) -> get_dc(ds, ref),
        keys = x -> isempty(propertynames(x)) ? nothing : propertynames(x),
        getindex = getproperty,
    )
    ds.shaped_metadata[:sols] = sols
    ds.reconstruction_caches[:op] = Dict{ScopeRef,Array{Float64,ndims(sols)}}()
end

function DCSolution(sols::AbstractArray{<:AbstractODESolution})
    sol_checks(sols)

    ds = SolutionSet(:DC, size(sols))
    Parameters!(ds, sols)
    DCSolution!(ds, sols)
    return ds
end

function cache_dc!(ss::SolutionSet, refs::Vector{<:ScopeRef})
    # DC uses the same reconstruction function as `tran`
    return cache!(ss, :op, refs, build_tran_reconstruct) do metadata, uncached_refs, reconstruct
        sol = metadata[:sols]
        vars, obs = split_and_sort_syms(uncached_refs)
        prob = sol.prob
        p = prob.p
        u0 = something(prob.u0, Float64[])
        u_vars = similar(u0, length(vars))
        u_obs = similar(u0, length(obs))

        if isa(prob, DAECompiler.DAEProblem)
            reconstruct(u_vars, u_obs, zero(sol.u[1]), sol.u[1], p, sol.t[1])
        else
            reconstruct(u_vars, u_obs, sol.u[1], p, sol.t[1])
        end

        out_by_ref = join_syms_split(uncached_refs, u_vars[:,:], u_obs[:,:], (vars, obs))
        return only.(out_by_ref)
    end
end
cache_dc!(ss::SolutionSet, ref::ScopeRef) = cache_dc!(ss, [ref])

function get_dc(ss::SolutionSet, probe::Union{ScopeRef,Probe}, idxs = [Colon() for _ in 1:ndims(ss)])
    reconstructed = only(cache_dc!(ss, ScopeRef(ss, probe)))

    # Our DC values don't have a time component, so just return the `u` values
    # according to the requested `idxs`
    function ctor(idx)
        return reconstructed[idx]
    end
    return ctor.(CartesianIndices(reconstructed)[idxs...])
end
