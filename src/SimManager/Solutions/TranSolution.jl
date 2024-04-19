const TransientSolutionType = SolutionSet{Val{:Transient}}
const SurrogateSolutionType = SolutionSet{Val{:Surrogate}}

function TranSolution!(ts::SolutionSet, sols::AbstractArray{<:AbstractODESolution}, ilss::AbstractArray{<:IndependentlyLinearizedSolution})
    prob = first(sols).prob
    ts.outputs[:tran] = TabCompleter(
        "Transient Signals",
        get_transformed_sys(prob).state.sys;
        leaf = (k, ref) -> get_tran(ts, ref),
        keys = x -> isempty(propertynames(x)) ? nothing : propertynames(x),
        getindex = getproperty,
    )
    if isa(prob, ODEProblem)
        ts.outputs[:tran_derivative] = TabCompleter(
            "Transient Time Derivative Signals",
            get_transformed_sys(prob).state.sys;
            leaf = (k, ref) -> get_tran_dt(ts, ref),
            keys = x -> isempty(propertynames(x)) ? nothing : propertynames(x),
            getindex = getproperty,
        )
    end
    ts.shaped_metadata[:sols] = sols
    ts.shaped_metadata[:ilss] = ilss
    # The `:tran` reconstruction cache maps from:
    #  ref -> sols-shaped array of (ts, yvals)
    ts.reconstruction_caches[:tran]    = Dict{ScopeRef,Array{Tuple{Vector{Float64},AbstractVector{Float64}},ndims(sols)}}()
    ts.reconstruction_caches[:tran_dt] = Dict{ScopeRef,Array{Tuple{Vector{Float64},AbstractVector{Float64}},ndims(sols)}}()
end

function TranSolution(sols::AbstractArray{<:AbstractODESolution}, ilss::AbstractArray{<:IndependentlyLinearizedSolution})
    sol_checks(sols)

    ts = SolutionSet(:Transient, size(sols))
    Parameters!(ts, sols)
    DCSolution!(ts, sols)
    TranSolution!(ts, sols, ilss)
    return ts
end

# Helper function to compile the reconstruct function for the particular uncached
# refs that the caching system needs to reconstruct.
function build_tran_reconstruct(ss, uncached_refs)
    ro = first(getfield(ss, :shaped_metadata)[:sols]).prob.f.observed
    vars, obs = split_and_sort_syms(uncached_refs)
    return get!(ro.cache, (vars, obs)) do
        compile_batched_reconstruct_func(ro.tsys, vars, obs, isa(ro, DAECompiler.DAEReconstructedObserved))
    end
end

# Same as above, but for the time derivative reconstruction function
function build_tran_dt_reconstruct(ss, uncached_refs)
    ro = first(getfield(ss, :shaped_metadata)[:sols]).prob.f.observed
    vars, obs = split_and_sort_syms(uncached_refs)
    return get!(ro.cache, (vars, obs)) do
        construct_reconstruction_time_derivative(ro.tsys, vars, obs, isa(ro, DAECompiler.DAEReconstructedObserved))
    end
end

# Helper function to dispatch on the type of `prob`
function tran_reconstruction_loop!(out_vars, out_obs, slice, prob, reconstruct)
    p = prob.p
    u0 = something(prob.u0, Float64[])
    u_vars = similar(u0, size(out_vars, 1))
    u_obs = similar(u0, size(out_obs, 1))

    # Run a loop over `slice`, reconstructing outputs at each timepoint.
    # If we're a `DAEProblem`, we need `du` for each timepoint, so get
    # that from `ils_dt`.  Since `ils_dt` is not necessarily sampled at
    # the correct timepoints, just get the values from it up-front
    # via sampling it 
    for (t_idx, (t, us)) in enumerate(slice)
        # iterating over `slice()` is giving us `u` and `du` as two columns in `us`:
        u = us[:, 1]
        if isa(prob, DAECompiler.DAEProblem)
            du = us[:, 2]
            reconstruct(u_vars, u_obs, du, u, p, t)
        else
            reconstruct(u_vars, u_obs, u, p, t)
        end
        out_vars[:, t_idx] .= u_vars
        out_obs[:, t_idx] .= u_obs
    end
end

function tran_dt_reconstruction_loop!(out_vars, out_obs, slice, prob, reconstruct)
    p = prob.p
    u0 = something(prob.u0, Float64[])
    u_vars = similar(u0, size(out_vars, 1))
    u_obs = similar(u0, size(out_obs, 1))

    # We don't yet know what the DAE form of this looks like
    if isa(prob, DAECompiler.DAEProblem)
        throw(ArgumentError("DAE form not yet supported"))
    end

    for (t_idx, (t, us)) in enumerate(slice)
        u = us[:, 1]
        du = us[:, 2]
        reconstruct(u_vars, u_obs, du, u, p, t)
        out_vars[:, t_idx] .= u_vars
        out_obs[:, t_idx] .= u_obs
    end
end

function cache_tran!(ss::SolutionSet, refs::Vector{<:ScopeRef}, cache_name = :tran)
    if cache_name == :tran
        build_reconstruct = build_tran_reconstruct
        reconstruct_loop! = tran_reconstruction_loop!
    elseif cache_name == :tran_dt
        build_reconstruct = build_tran_dt_reconstruct
        reconstruct_loop! = tran_dt_reconstruction_loop!
    else
        throw(ArgumentError("cache_name must be :tran or :tran_dt!"))
    end

    # Cache all uncached refs
    cache!(ss, cache_name, refs, build_reconstruct) do metadata, uncached_refs, reconstruct
        sol = metadata[:sols]
        ils = metadata[:ilss]
        dependent_u_idxs = Set(dependent_states(sol, uncached_refs))

        # Reconstruct the `u` indices we care about, replacing the indices we don't care about with `0.0`
        slice = ILSSlice(ils, dependent_u_idxs)

        vars, obs = split_and_sort_syms(uncached_refs)
        prob = sol.prob
        u0 = something(prob.u0, Float64[])
        out_vars = similar(u0, (length(vars), length(slice)))
        out_obs  = similar(u0, (length(obs), length(slice)))
        reconstruct_loop!(out_vars, out_obs, slice, prob, reconstruct)

        # Collect the output for each `ref`, then pair it with its time vector.
        # Currently, all time vectors are the same, but this may not always be the case.
        out_by_ref = join_syms_split(uncached_refs, out_vars, out_obs, (vars, obs))
        return [(slice.ils.ts, out) for out in out_by_ref]
    end
end
cache_tran!(ss, ref::ScopeRef, args...) = cache_tran!(ss, [ref], args...)

function get_tran(ss::SolutionSet, probe::Union{ScopeRef,Probe}, idxs = [Colon() for _ in 1:ndims(ss)])
    reconstructed = only(cache_tran!(ss, ScopeRef(ss, probe), :tran))

    # Convert reconstructed values to signals.  We know that for a single probe
    # there is a single timeseries, so we just index the first one:
    function signal_ctor(idx)
        t, u = reconstructed[idx]
        return Signal(t, u)
    end
    return signal_ctor.(CartesianIndices(reconstructed)[idxs...])
end

function get_tran_dt(ss::SolutionSet, probe::Union{ScopeRef,Probe}, idxs = [Colon() for _ in 1:ndims(ss)])
    reconstructed = only(cache_tran!(ss, ScopeRef(ss, probe), :tran_dt))

    # Convert reconstructed values to signals.  We know that for a single probe
    # there is a single timeseries, so we just index the first one:
    function signal_ctor(idx)
        t, u = reconstructed[idx]
        return Signal(t, u)
    end
    return signal_ctor.(CartesianIndices(reconstructed)[idxs...])
end
