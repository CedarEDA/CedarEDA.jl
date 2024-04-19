const SensitivitySolutionType = SolutionSet{Val{:Sensitivity}}

function SensitivitySolution!(ss::SolutionSet, sols::AbstractArray{<:AbstractODESolution}, ilss::AbstractArray{<:IndependentlyLinearizedSolution})
    prob = first(sols).prob
    # 'sensitivities' are the sensitivities of each output with respect to a parameter
    # So we build a TabCompleter that first selects the scoperef, then selects which parameter
    ss.outputs[:sensitivities] = TabCompleter(
        "Sensitivities",
        get_transformed_sys(prob).state.sys;
        keys = x -> isempty(propertynames(x)) ? nothing : propertynames(x),
        getindex = getproperty,
        leaf = (_, ref) -> begin
            return TabCompleter(
                "Sensitivities",
                # Make sure that we only use the parameters in the parameterization here,
                # not the full set of parameters.
                [sol.prob.p.params for sol in sols];
                leaf = (param_name, _) -> get_sensitivity(ss, ref, param_name, [Colon() for _ in 1:ndims(ss)]),
            )
        end,
    )
    ss.shaped_metadata[:sols] = sols
    ss.shaped_metadata[:ilss] = ilss
    ss.reconstruction_caches[:sensitivities] = Dict{ScopeRef,Array{Tuple{Vector{Float64},Vector{Vector{Float64}}},ndims(sols)}}()
end

function SensitivitySolution(sols::AbstractArray{<:AbstractODESolution}, ilss::AbstractArray{<:IndependentlyLinearizedSolution})
    sol_checks(sols)

    ss = SolutionSet(:Sensitivity, size(sols))
    Parameters!(ss, sols)
    DCSolution!(ss, sols)
    TranSolution!(ss, sols, ilss)
    SensitivitySolution!(ss, sols, ilss)
    return ss
end

function build_sensitivity_reconstruct(ss, uncached_refs)
    sol = first(getfield(ss, :shaped_metadata)[:sols])
    tsys = get_transformed_sys(sol)
    ro = sol.prob.f.observed
    vars, obs = split_and_sort_syms(uncached_refs)
    return get!(ro.derivative_cache, (vars, obs, false)) do
        compile_batched_reconstruct_derivatives(tsys, vars, obs, false, isa(ro, DAECompiler.DAEReconstructedObserved))
    end
end

function cache_sensitivity!(ss::SolutionSet, refs::Vector{<:ScopeRef})
    # At the moment, we always reconstruct an entire `ref` at once, across all parameters.
    # This is because a single `reconstruct()` call reconstructs for all parameters at once.
    return cache!(ss, :sensitivities, refs, build_sensitivity_reconstruct) do metadata, uncached_refs, dreconstruct!
        sol = metadata[:sols]
        ils = metadata[:ilss]
        num_primal_states = sol.prob.f.numindvar
        num_params = sol.prob.f.numparams
        dependent_u_idxs = Set(dependent_states(sol, uncached_refs))

        # Construct value cache set of all the u and du indices that we care about.
        # This ensures that we can obtain `u`/`du` pieces for each 
        slice = ILSSlice(ils, dependent_u_idxs)

        # Splitter to separate `u` from `du` after we iterate over `slice`
        split_sensitivities(u_combined) = (u_combined[1:num_primal_states], u_combined[(num_primal_states+1):end])

        vars, obs = split_and_sort_syms(uncached_refs)
        prob = sol.prob
        p = prob.p
        u0 = something(prob.u0, Float64[])
        dout_vars_per_param = [similar(u0, (length(vars), length(slice))) for _ in 1:num_params]
        dout_obs_per_param  = [similar(u0, (length(obs), length(slice))) for _ in 1:num_params]
        dvars_du = similar(u0, length(vars), num_primal_states)
        dvars_dp = similar(u0, length(vars), num_params)
        dobs_du = similar(u0, length(obs), num_primal_states)
        dobs_dp = similar(u0, length(obs), num_params)

        # Run a loop over timepoints in `vcs`, reconstructing outputs at each timepoint.
        for (t_idx, (t, us)) in enumerate(slice)
            # iterating over `slice()` is giving us `u` and `du` as two columns in `us`:
            u = us[:, 1]
            du = us[:, 2]

            u, du_dparams = split_sensitivities(u)

            # We don't support DAEProblem formulations yet
            dreconstruct!(dvars_du, dvars_dp, dobs_du, dobs_dp, u, p, t)

            for param_idx in 1:num_params
                du_dparams_idxs = (num_primal_states*(param_idx-1)+1):(num_primal_states*param_idx)
                dvars_dp[:, param_idx] += dvars_du * du_dparams[du_dparams_idxs]
                dobs_dp[:, param_idx] += dobs_du  * du_dparams[du_dparams_idxs]
                dout_vars_per_param[param_idx][:, t_idx] .= dvars_dp[:, param_idx]
                dout_obs_per_param[param_idx][:, t_idx]  .= dobs_dp[:, param_idx]
            end
        end

        # Collect the output for each `ref`, where for each `ref` we assemble
        # a collection of outputs, one per parameter we have sensitivity with respect to.
        # This is called "inverted" because it is params then refs, instead of refs then params.
        inverted = join_syms_split.(
            (uncached_refs,),
            dout_vars_per_param,
            dout_obs_per_param,
            ((vars, obs),),
        )
        return [
            (slice.ils.ts, [inverted[param_idx][ref_idx] for param_idx in 1:num_params])
            for ref_idx in 1:length(uncached_refs)
        ]
    end
end
cache_sensitivity!(ss::SolutionSet, ref::ScopeRef) = cache_sensitivity!(ss, [ref])

function get_sensitivity(ss::SolutionSet, probe::Union{ScopeRef,Probe}, param_name::Symbol, idxs)
    reconstructed = only(cache_sensitivity!(ss, ScopeRef(ss, probe)))
    param_idx = findfirst_param(ss, param_name)
    function signal_ctor(idx)
        t, us_per_params = reconstructed[idx]
        return Signal(t, us_per_params[param_idx])
    end
    return signal_ctor.(CartesianIndices(reconstructed)[idxs...])
end
