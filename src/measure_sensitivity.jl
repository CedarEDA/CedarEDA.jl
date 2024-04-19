using DAECompiler: DAECompiler, batch_reconstruct, ScopeRef
using SciMLSensitivity: ODEForwardSensitivityProblem
using OrdinaryDiffEq
using Diffractor
using Diffractor: ZeroBundle, TaylorBundle, ∂☆, primal, first_partial
using ChainRulesCore: ChainRulesCore, Tangent, ZeroTangent, frule

export value_and_params_gradient, sample_at

function prepare_measurement_sensitivity(sp)   
    # use the sensitivities cache, but don't log anything cos we are going to be calling this in a loop
    with_logger(NullLogger()) do
        ts = sensitivities!(sp)
        ssol = first(getfield(ts, :shaped_metadata)[:sols])
        return ts, ssol
    end
end

measure_frule(measure, ts, ssol, ṗarams) = measure_frule(measure.original_function, measure, ts, ssol, ṗarams)
measure_frule(_, measure, _, _, _) = throw(ArgumentError("Derivatives of $measure are not currently supported."))

function measure_frule(::Union{typeof(risetime), typeof(falltime)}, measure, ts, ssol, ṗarams)
    result = CedarEDA.apply(ts, measure, [1])
    t = [result.pt1.x, result.pt2.x]  # we will compute for the end-points
    ṫ = pushforward_measure(measure, ts, ssol, ṗarams, t)
    return result, Tangent{typeof(result)}(
        pt1 = Tangent{CrossMeasure}(x=ṫ[1]),
        pt2 = Tangent{CrossMeasure}(x=ṫ[2]),
        values = [ṫ[2] - ṫ[1]]
    )
end

function measure_frule(::Union{typeof(risetimes), typeof(falltimes)}, measure, ts, ssol, ṗarams)
    results = CedarEDA.apply(ts, measure, [1])
    # put the start times in first half and the end times in second half
    t = [[r.pt1.x for r in results]; [r.pt2.x for r in results]]
    ṫ = pushforward_measure(measure, ts, ssol, ṗarams, t)
    ṫ_starts = @view ṫ[1:end÷2]
    ṫ_ends = @view ṫ[end÷2:end]
    ṙesults = map(results, ṫ_starts, ṫ_ends) do result, ṫ1, ṫ2
        Tangent{typeof(result)}(
            pt1 = Tangent{CrossMeasure}(x=ṫ1),
            pt2 = Tangent{CrossMeasure}(x=ṫ2),
            values = [ṫ2 - ṫ1]
        )
    end
    return results, ṙesults
end

function measure_frule(::Union{typeof(delay)}, measure, ts, ssol, ṗarams)
    result = CedarEDA.apply(ts, measure, [1])
    t = [result.pt1.x, result.pt2.x]
    ṫ = CedarEDA.pushforward_measure(measure, ts, ssol, ṗarams, t)
    @assert size(ṫ) == (2, 2)
    # We actually only need the diagonal since that is (probe1,time1), and (probe2,time2)
    return result, Tangent{typeof(result)}(
        pt1 = Tangent{CrossMeasure}(x=ṫ[1,1]),
        pt2 = Tangent{CrossMeasure}(x=ṫ[2,2]),
        values = [ṫ[2] - ṫ[1]]
    )
end

function measure_frule(::typeof(delays), measure, ts, ssol, ṗarams)
    results = CedarEDA.apply(ts, measure, [1])
    # put the start times in first half and the end times in second half
    t = [[r.pt1.x for r in results]; [r.pt2.x for r in results]]
    ṫ = pushforward_measure(measure, ts, ssol, ṗarams, t)
    ṫ_starts = @view ṫ[1, 1:end÷2]  # row 1 is probe 1, and we want start times
    ṫ_ends = @view ṫ[2, end÷2:end]  # row 2 is probe 2, and we want end times
    ṙesults = map(results, ṫ_starts, ṫ_ends) do result, ṫ1, ṫ2
        Tangent{typeof(result)}(
            pt1 = Tangent{CrossMeasure}(x=ṫ1),
            pt2 = Tangent{CrossMeasure}(x=ṫ2),
            values = [ṫ2 - ṫ1]
        )
    end
    return results, ṙesults
end

# Returns a vector of signal values instead of a Signal, to avoid
# avoid differentiating too much CedarWaves/plotting code.
function sample_at end
sample_at(probe, t) = FunctionMeasure([probe], s->s.f.(t), "sample_at", sample_at)

function CedarEDA.measure_frule(::typeof(sample_at), measure, ts, ssol, ṗarams)
    v = CedarEDA.apply(ts, measure, [1])
    @assert v isa Vector
    refs = map(probe -> ScopeRef(ts, probe), measure.probes)
    ṡsol = Tangent{typeof(ssol)}(prob = Tangent{typeof(ssol.prob)}(p = ṗarams));
    _, v̇ = frule(
        (ZeroTangent(), ṡsol, ZeroTangent(), ZeroTangent()),
        batch_reconstruct, ssol, refs, measure.fn.t
    )
    @assert size(v̇) == (1, length(v))  # row vector
    return v, v̇
end

function pushforward_measure(measure, timeseries, ssol, ṗarams, t)
    refs = map(probe -> ScopeRef(timeseries, probe), measure.probes)

    ∂t = ones(size(t))
    _, ft = frule((ZeroTangent(), ZeroTangent(), ZeroTangent(), ∂t), batch_reconstruct, ssol, refs, t)
    # PREMOPT: above could use `reconstruct_time_deriv` directly, to avoid computing batch_reconstruct
    # PREMOPT: all the above is shared for all different values of ṗarams.

    ṡsol = Tangent{typeof(ssol)}(prob = Tangent{typeof(ssol.prob)}(p = ṗarams));
    _, fp = frule(
        (ZeroTangent(), ṡsol, ZeroTangent(), ZeroTangent()),
        batch_reconstruct, ssol, refs, t
    )
    # PREMOPT: above could use `reconstruct_deriv` directly, to avoid computing batch_reconstruct

    ṫ = -fp ./ ft
    # if fp is zero then parameter does not influence time so definitionally zero (removes NaNs etc)
    # We see this e.g. if measuring a signal like a ideal voltage source where parameters have no influence on timing
    ṫ[iszero.(fp)] .= zero(eltype(ṫ))
    return ṫ
end 


(r::FunctionMeasure)(sp::SimParameterization, idxs=[1]) = apply(tran!(sp), r, idxs)

function ChainRulesCore.frule((ṁeasure, ṡp, _), measure::FunctionMeasure, sp, idx)
    iszero(ṁeasure) || return ChainRulesCore.@not_implemented "derivatives wrt the measurement parameters"
    idx == [1] || throw("derivatives not supported for sweeps of length greater than 1")

    @debug "solving"
    ts, ssol = prepare_measurement_sensitivity(sp)   # TODO avoid repeating this step for multiple things being pushed forward (cache in sm?)
    @debug "solve complete, pusing forward"
    ṗarams = only(ṡp.params)
    ret = measure_frule(measure, ts, ssol, ṗarams)
    @debug "pushing forward complete" ret
    return ret
end

"""
    value_and_params_gradient(loss, sp)

Given an arbitary loss function, which likely calls `measure(sp)` for some measure)
compute its value and its gradient with respect to each parameter specified in `sp`.
"""
function value_and_params_gradient(loss, sp)
    if !(sp.params isa CedarSim.SweepFlattener{<:Base.Iterators.ProductIterator})
        # This is because of how we encode the intitial tangents. But maybe there is a smarter way to do this?
        throw(ArgumentError("Only simulations parameterized with a length 1 ProductSweep support gradients. Not $(typeof(sp.params))."))
    end
    if length(sp.params) == 0
        throw(ArgumentError("Simulation has no parameters"))
    elseif length(sp.params) > 1
        throw(ArgumentError("Concurrent gradient computation over sweeps of parameters (of length > 1) is not supported."))
    end

    params = CedarSim.sweep_example(sp.params)
    params_tangent_basis = map(enumerate(params)) do (ii,p)
        t = zeros(length(params))
        t[ii] = 1
        t
    end

    local the_primal
    the_gradient = map(params_tangent_basis) do params_tangent
        sp_tan = Tangent{SimParameterization}(
            params = Tangent{typeof(sp.params)}(
                # We are doing a mildly hacky custom tangent type here. Relies on having needed overloads for linear operators
                # on Tangent{<:CedarSim.SweepFlattener, <:NamedTuple} (which is an intended feature, but rarely used)
                v=params_tangent
            )
        )
        sp_bun = TaylorBundle{1}(sp, (sp_tan,))
        loss_bun = ∂☆{1}()(ZeroBundle{1}(loss), sp_bun)
        the_primal = primal(loss_bun)
        return first_partial(loss_bun)
    end
    return the_primal, the_gradient
end

# We implement out own overloads for these functions of Tangents of SweepFlatteners because we don't want to be required to fully match the structure
Base.first(t::Tangent{<:CedarSim.SweepFlattener, <:NamedTuple}) = first(ChainRulesCore.backing(t))
Base.only(t::Tangent{<:CedarSim.SweepFlattener, <:NamedTuple}) = only(ChainRulesCore.backing(t))
