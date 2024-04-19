using DAECompiler: TransformedIRODESystem, IRODESystem, ScopeRef, batch_reconstruct, compile_batched_reconstruct_func, compile_batched_reconstruct_derivatives, construct_reconstruction_time_derivative, split_and_sort_syms, get_transformed_sys
using SciMLBase: AbstractODESolution, DAEProblem
using CedarSim: DescriptorStateSpace
import DiffEqCallbacks: iteration_state

export SolutionSet

"""
    SolutionSet

A structure representing a set of solutions, typically from a `tran!()`,
`sensitivities!()`, `ac!()` or `dc!()` call.  Holds outputs in such a way as to
make it easy to access probe points across the entire sweep of solves as well as
single parameter points.

Different analyses result in `SolutionSet` objects with different properties:

* A [`tran!()`](@ref) solution contains `op`, `tran` and `parameters`
  properties, which hold the DC operating point, transient signal, and
  simulation parameters, respectively.

* A [`dc!()`])(@ref) solution contains just `op` and `parameters`.

* An [`ac!()`](@ref) solution contains `op`, `ac` and `parameters`,
  where `ac` holds the frequency response curves.

* A [`sensitivities!()`](@ref) solution contains `op`, `tran`, `sensitivities`
  and `parameters` properties, where `sensitivities` are indexed first by the
  parameter the sensitivities are calculated with respect to, then the signal
  to probe for sensitivities.

Example usage:

    ts = tran!(sp)

    # This returns an array of solutions for the `node_vout` probe
    ss.tran.node_vout

    # Index into it to get a single solution
    ss.tran.node_vout[1]

    # Transient analysis requires an initial DC operating point,
    # which you can obtain via the following:
    ss.dc.node_vout[2:5]

    # Similarly, we can collect parameters from the solution
    ss.parameters.cload[end]
"""
struct SolutionSet{NAME}
    shape::Tuple

    # outputs contains things like `:op`, `:tran`, `:sensitivities`, `:parameters`, etc...
    outputs::Dict{Symbol,<:TabCompleter}

    # metadata contains things like `:sols`, `:ilss`, and all elements must be the same size as `shape`
    # These are still accessible through `getproperty()`, but they're not advertised.
    shaped_metadata::Dict{Symbol,<:AbstractArray}
    unshaped_metadata::Dict{Symbol,Any}

    # The caches for our reconstructions
    reconstruction_caches::Dict{Symbol,Dict{ScopeRef,<:AbstractArray}}

    function SolutionSet(name::Symbol,
                         shape::Tuple,
                         outputs::Dict{Symbol,<:TabCompleter},
                         metadata::Dict{Symbol,<:AbstractArray},
                         unshaped_metadata::Dict{Symbol,<:Any},
                         reconstruction_caches)
        return new{Val{name}}(shape, outputs, metadata, unshaped_metadata, reconstruction_caches)
    end
end

function SolutionSet(name, shape::Tuple)
    return SolutionSet(
        Symbol(name),
        shape,
        Dict{Symbol,TabCompleter}(),
        Dict{Symbol,AbstractArray}(),
        Dict{Symbol,Any}(),
        Dict{Symbol,Dict{ScopeRef,AbstractArray}}(),
    )
end

function sol_checks(sols)
    # Check that all sols are of the same prob:
    prob = first(sols).prob
    for sol in sols
        if get_transformed_sys(sol) != get_transformed_sys(prob)
            throw(ArgumentError("All solutions must be of the same underlying system"))
        end
    end
end

function Parameters!(ss::SolutionSet, sols::AbstractArray{<:AbstractODESolution})
    # TODO: Once https://github.com/JuliaComputing/CedarSim.jl/issues/606
    # has landed, change this to instead use that to extract the _full_
    # set of parameters from the `ParamSim` objects on-demand!
    normalize_params(sim) = NamedTuple()
    normalize_params(sim::ParamSim) = sim.params
    ss.outputs[:parameters] = TabCompleter(
        "Parameters",
        [normalize_params(sol.prob.p) for sol in sols],
    )
end

# Helper function for converting a `Probe` -> `ScopeRef`
function DAECompiler.ScopeRef(ss::SolutionSet, probe::Probe)
    prob = first(getfield(ss, :shaped_metadata)[:sols]).prob
    sys = get_transformed_sys(prob).state.sys
    return getproperty(sys, probe)
end
DAECompiler.ScopeRef(::SolutionSet, ref::ScopeRef) = ref

function get_param_names(ss::SolutionSet)
    prob = first(getfield(ss, :shaped_metadata)[:sols]).prob
    return propertynames(prob.p.params)
end

function findfirst_param(ss::SolutionSet, name::Symbol)
    param_names = get_param_names(ss)
    idx = findfirst(==(name), param_names)
    if idx === nothing
        throw(ArgumentError("Unable to find parameter '$(name)'"))
    end
    return idx
end

Base.size(ss::SolutionSet) = getfield(ss, :shape)
Base.length(ss::SolutionSet) = prod(size(ss))
Base.ndims(ss::SolutionSet) = length(size(ss))

# Only show what we want the user to interact with [^_^]
Base.propertynames(ss::SolutionSet) = keys(getfield(ss, :outputs))

function Base.show(io::IO, ss::SolutionSet{<:Val{name}}) where {name}
    if ndims(ss) == 1
        print(io, "$(size(ss)[1])-element $(name) Solution")
    else
        print(io, "$(join(size(ss),"×")) $(name) Solution")
    end
end

function dependent_states(sol::AbstractODESolution, refs::Vector{<:ScopeRef})
    # TODO: We should figure out which `u` indices the `ref` depends on, then only
    # reconstruct a matrix sampled at the union of the specified entries in `value_caches`.
    # This will allow us to greatly reduce the number of timepoints we are reconstructing here.
    # Because our reconstruction function requires a full `u` vector to actually reconstruct,
    # the plan is to just provide `NaN` in `u` entries that we do not expect to read from.
    if isa(sol.prob.f, SciMLSensitivity.ODEForwardSensitivityProblem)
        return 1:sol.prob.f.numindvar
    else
        isnothing(sol.prob.u0) && return 1:0
        return 1:length(sol.prob.u0)
    end
end

function has_cache_key(ss::SolutionSet, cache_name::Symbol, ref::ScopeRef)
    rcs = getfield(ss, :reconstruction_caches)
    return haskey(rcs[cache_name], ref)
end

function cache!(callback::Function, ss::SolutionSet, cache_name::Symbol, refs::Vector{<:ScopeRef}, build_reconstruct::Function = (ss, refs) -> nothing)
    uncached_refs = filter(ref -> !has_cache_key(ss, cache_name, ref), refs)
    rcs = getfield(ss, :reconstruction_caches)
    if !isempty(uncached_refs)
        shape = getfield(ss, :shape)
        metadata = getfield(ss, :shaped_metadata)
        results_by_ref = [Array{eltype(valtype(rcs[cache_name]))}(undef, shape) for _ in uncached_refs]
        reconstruct = build_reconstruct(ss, uncached_refs)

        Threads.@threads for idx in 1:prod(shape)
            # TODO: Don't allocate a new Dict every time, allocate a bunch of Dict's, potentially using `TaskLocalValues.jl`?
            metadata_idx = Dict{Symbol,Any}(key => val[idx] for (key, val) in metadata)
            for (ref_idx, result) in enumerate(callback(metadata_idx, uncached_refs, reconstruct))
                results_by_ref[ref_idx][idx] = result
            end
        end
        for (ref_idx, result) in enumerate(results_by_ref)
            rcs[cache_name][uncached_refs[ref_idx]] = result
        end
    end

    return [rcs[cache_name][ref] for ref in refs]
end

"""
    @unroll for v in itr
        ...
    end

Unrolls applied for loop. `itr` must be an object that can be evaluated at macro-expansion time.
"""
macro unroll(ex)
    Meta.isexpr(ex, :for) || error("Expected a valid for loop expression")
    length(ex.args) == 2 || error("Expected a valid for loop expression")
    itr, body = ex.args
    (Meta.isexpr(itr, :(=)) && Meta.isexpr(body, :block)) ||
        error("Expected a valid for loop expression")
    itrname = itr.args[1]
    itrvals = try
        Core.eval(__module__, itr.args[2])
    catch
        error("`itr` couldn't be evaluated at macro expansion time")
    end
    ret = Expr(:block)
    for itrval = itrvals
        body′ = copy(body)
        pushfirst!(body′.args, :($itrname = $(QuoteNode(itrval))))
        push!(ret.args, Expr(:let, Expr(:block), esc(body′)))
    end
    return ret
end

function Base.getproperty(ss::SolutionSet, name::Symbol)
    # Special override for names in `outputs`, then `shaped_metadata`, then `unshaped_metadata`
    @unroll for parent in (:outputs, :shaped_metadata, :unshaped_metadata)
        values = getfield(ss, parent)
        if name ∈ keys(values)
            return values[name]
        end
    end
    return getfield(ss, name)
end

"""
    ILSSlice

Helper object that slices [`IndependentlyLinearizedSolution`](https://github.com/SciML/DiffEqCallbacks.jl/blob/08933b573d1596ad2501f29ad70c35e268bf33d4/src/independentlylinearizedutils.jl#L153-L164) objects as
stored into by the [`LinearizingSavingCallback()`](https://github.com/SciML/DiffEqCallbacks.jl/blob/08933b573d1596ad2501f29ad70c35e268bf33d4/src/saving.jl#L332-L365) from [`DiffEqCallbacks`](https://github.com/SciML/DiffEqCallbacks.jl)
by state index.  Example usage:

```julia
# Construct slice on states 1, 3 and 7
u_idxs = [1, 3, 7]
slice = ILSSlice(ils, u_idxs)

# Iterate over saved points in the linearization
for (t_idx, (t, us)) in enumerate(slice)
    # iterating over `slice()` is giving us `u` and `du` as two columns in `us`:
    u = us[:, 1]
    du = us[:, 2]
    ...
end
```

This structure is used internally by all `SolutionSet` objects that deal with
timeseries-like data, such as the output of [`tran!()`](@ref) or [`sensitivities!()`](@ref).
"""
struct ILSSlice{T,S}
    ils::IndependentlyLinearizedSolution{T,S}
    idxs::Vector{Int}
    u_full::Matrix{S}  # 1 row per state, 1 column per level of derivative 

    function ILSSlice(ils::IndependentlyLinearizedSolution{T,S}, idxs) where {T, S}
        idxs = sort(collect(idxs))
        keep_t_idxs = Int[]
        for t_idx in 1:length(ils)
            if any(ils.time_mask[idxs, t_idx])
                push!(keep_t_idxs, t_idx)
            end
        end

        # New, sliced ILS for the primal
        ils_sliced = IndependentlyLinearizedSolution(
            ils.ts[keep_t_idxs],
            ils.us[idxs],
            ils.time_mask[idxs, keep_t_idxs],
            nothing,
        )

        return new{T,S}(
            ils_sliced,
            idxs,
            Matrix{S}(undef, DiffEqCallbacks.num_us(ils), DiffEqCallbacks.num_derivatives(ils)),
        )
    end
end

function Base.iterate(slice::ILSSlice, ils_state = iteration_state(slice.ils))
    # Iterate on the ILS
    ret = iterate(slice.ils, ils_state)
    if ret === nothing
        return nothing
    end
    (t, u_compressed), ils_state = ret
    slice.u_full .= 0.0
    slice.u_full[slice.idxs, :] .= u_compressed

    return ((t, slice.u_full), ils_state)
end
Base.length(slice::ILSSlice) = length(slice.ils)

"""
    join_syms_split(refs, out_vars, out_obs, (vars_inds, obs_inds))

Similar to DAECompiler's `join_syms()`, but instead of copying `out_vars` and `out_obs`
to a new `Matrix`, returns a vector of views into those matrices.  This can be thought of
as a zero-copy version of `join_syms`, meant to have these vectors inserted into a
`SolutionSet`'s internal `reconstruction_caches` object.
"""
function join_syms_split(refs::Vector{<:ScopeRef},
                         vars::AbstractMatrix,
                         obs::AbstractMatrix,
                         (var_inds, obs_inds)=DAECompiler.split_and_sort_syms(refs))
    out = Vector{AbstractVector}(undef, length(refs))
    out_idx = 1
    vars_idx = 1
    obs_idx = 1
    for (out_idx, ref) in enumerate(refs)
        (is_obs, idx) = DAECompiler._sym_to_index(ref)
        if is_obs
            loc=findfirst(==(idx), obs_inds)
            out[out_idx] = @view(obs[loc, :])
            obs_idx += 1
        else
            loc=findfirst(==(idx), var_inds)
            out[out_idx] = @view(vars[loc, :])
            vars_idx += 1
        end
    end
    return out
end

include("Solutions/ACSolution.jl")
include("Solutions/NoiseSolution.jl")
include("Solutions/DCSolution.jl")
include("Solutions/TranSolution.jl")
include("Solutions/SensitivitySolution.jl")
