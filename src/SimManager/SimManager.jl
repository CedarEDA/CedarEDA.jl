using SciMLBase, DAECompiler, CedarSim, BSIM4, DiffEqCallbacks
using CedarSim: SpectreNetlistParser, VerilogAParser
using CedarSim.SpectreEnvironment
import CedarSim: get_default_parameterization
using Sundials, OrdinaryDiffEq, Printf
using SciMLBase: AbstractDEProblem, AbstractODESolution, DEIntegrator
using Dates, Serialization
import LinearAlgebra
import DescriptorSystems

export SimManager, SimParameterization, set_checks!, set_saved_signals!, tran!, dc!, sensitivities!,
       check, explore, is_success, show_timings, load_surrogate

displayname(x) = String(nameof(x))
displayname(x::Function) = "subcircuit"
displayname(x::Type{CedarSim.SimpleResistor}) = "resistor"
displayname(x::Type{CedarSim.SimpleCapacitor}) = "capacitor"
displayname(x::Type{CedarSim.SimpleInductor}) = "inductor"
displayname(x::Type{CedarSim.SimpleDiode}) = "diode"
displayname(x::Type{CedarSim.VoltageSource}) = "vsource"
displayname(x::Type{CedarSim.CurrentSource}) = "isource"


function count_models(dict::Dict, params::CedarSim.ParamObserver)
    for (name, val) in getfield(params, :params)
        if val isa CedarSim.ParamObserver
            mtype = displayname(getfield(val, :type))
            dict[mtype] = get(dict, mtype, 0) + 1
            count_models(dict, val)
        end
    end
end

abstract type AbstractSimManager; end

include("TabCompleter.jl")
include("Solutions.jl")
include("SimParameterization.jl")

const build_time = now()
const date_format = dateformat"yyyy-mm-dd HH:MM:SS"
"""
    SimManager

Top-level simulation manager; Load your netlist into this object, then create a
parameterization from it via `SimParameterization`.  That parameterization can
then be used to run various simulations.
"""
mutable struct SimManager <: AbstractSimManager
    # A single simuation is locked to a particular netlist and AST
    netlist_path::String
    ast
    circuit_func::Function

    # When we call `compute_structure()`, we compute with respect to our current
    # parameterization, e.g. which parameters are allowed to be changed.
    # This caches our structure computations for each set of parameters
    problems::Dict{Tuple{Set{Symbol},Type,Bool}, AbstractDEProblem}

    # When we want to solve, we cache our solutions based on their parameterization
    ac_solutions::Dict{Any, SolutionSet}
    noise_solutions::Dict{Any, SolutionSet}
    dc_solutions::Dict{SimParameterization, SolutionSet}
    tran_solutions::Dict{SimParameterization, SolutionSet}
    sensitivities::Dict{SimParameterization, SolutionSet}

    # for reporting time spent
    to::TimerOutput

    debug_config::NamedTuple # passed eventually to IRODESystem

    function SimManager(netlist_path::AbstractString;
                        # TODO: Don't automatically include `pkgdir(CedarSim)`
                        include_path::Vector{<:AbstractString} = [dirname(netlist_path), Base.pkgdir(CedarSim)],
                        debug_config=(;),
                        log_level=nothing, log_file=nothing  # deprecated
                    )
        if !isnothing(log_level) || !isnothing(log_file)
            Base.depwarn("log_level and log_file arguments to SimManager are deprecated. Use `configure_logging!` instead.", :SimManager)
            # this is not a perfect deprecation but just changing the global is close enough
            configure_logging!(; log_level, log_file)
        end

        to = TimerOutput()
        @info """Welcome to CedarEDA (v$(cedareda_version), $(build_time))
        System RAM free: $(Sys.free_memory()÷10^9) GB
        System Cores: $(Sys.CPU_THREADS) (using $(Threads.nthreads()))
        """
        @info "Parsing netlist $netlist_path"
        @log_timeit to "Code generation" begin
            #ast = SpectreNetlistParser.SPICENetlistParser.parsefile(netlist_path)
            @log_timeit to "Parsing" ast = SpectreNetlistParser.SpectreNetlistParser.parsefile(netlist_path)
            @log_timeit to "Lowering" code = CedarSim.make_spectre_circuit(ast, include_path);
            @log_timeit to "Evaluation" begin
                mod = Module()
                Core.eval(mod, :(using CedarSim))
                Core.eval(mod, :(using CedarSim.SpectreEnvironment))
                Core.eval(mod, :(using BSIM4))

                # TODO: Don't do this here, do it on-demand from within CedarSim
                bsimcmg_path = joinpath(dirname(pathof(VerilogAParser)), "../cmc_models/bsimcmg107/bsimcmg.va")
                if isfile(bsimcmg_path)
                    @log_timeit to "BSIMCMG" Core.eval(mod, :(const bsimcmg107 = $(load_VA_model(bsimcmg_path))))
                end

                circuit_func = Core.eval(mod, code)
            end

            # Do a sanity check of our circuit function
            @log_timeit to "Verification" try
                invokelatest(circuit_func)
            catch e
                @error("Circuit function has an error!  Please report this to the developers!")
                if log_file !== nothing
                    @debug "Dumping generated code"
                    @debug code
                end
                rethrow(e)
            end

            obs = CedarSim.ParamObserver()
            invokelatest(circuit_func, obs)
            b = IOBuffer()
            show(b, MIME("text/plain"), obs)
            @debug "Circuit structure:\n$(String(take!(b)))"
            counts = Dict{String, Int}()
            count_models(counts, obs)
            pairs = collect(counts)
            sort!(pairs)
            str = join((string(x, ":\t", y) for (x,y) in pairs), "\n")
            @info "Device summary:\n$str"

            return new(
                string(netlist_path),
                ast,
                circuit_func,
                Dict{Tuple{Set{Symbol},Type,Bool}, AbstractDEProblem}(),
                Dict{SimParameterization, AbstractArray{SolutionSet}}(),
                Dict{SimParameterization, AbstractArray{SolutionSet}}(),
                Dict{SimParameterization, AbstractArray{SolutionSet}}(),
                Dict{SimParameterization, AbstractArray{SolutionSet}}(),
                Dict{SimParameterization, AbstractArray{SolutionSet}}(),
                to,
                debug_config
            )
        end
    end
end

function print_timing(sm)
    io = IOBuffer()
    show(io, sm.to; sortby=:firstexec)
    @info String(take!(io))
    @info "Memory high water mark: $(TimerOutputs.prettymemory(Sys.maxrss()))"
end

get_default_parameterization(sm::SimManager) = get_default_parameterization(sm.ast)
get_default_sweep(sm::SimManager) = ProductSweep((Sweep(name => val) for (name, val) in get_default_parameterization(sm))...)

function Base.show(io::IO, sm::SimManager)
    print(io, "SimManager for '$(basename(sm.netlist_path))', with parameters:")
    for (name, default) in get_default_parameterization(sm)
        print(io, "\n - $(name) (default: $(CedarWaves.display_value(default)))")
    end
end


function build_problem(sm::SimManager, params, abstol_dc, problem_type, mode; jac::Bool = false, paramjac::Bool = false)
    sim = params === nothing ? DefaultSim(sm.circuit_func, mode) : ParamSim(sm.circuit_func; mode, CedarSim.sweep_example(params)...)
    params_list = params === nothing ? Set{Symbol}() : sweepvars(params)

    @info("Compiling $(basename(sm.netlist_path))", parameterization = collect(params_list), problem_type, jac)
    @log_timeit sm.to "Compilation" begin
        @log_timeit sm.to "System Analysis" sys = CircuitIRODESystem(sim; sm.debug_config)

        tspan = (0.0, 1.0)
        initializealg=CedarDCOp(; abstol=abstol_dc)
        @log_timeit sm.to "Problem Construction" if problem_type == DAEProblem
            prob = DAEProblem(sys, nothing, nothing, tspan, sim; jac, initializealg);
        elseif problem_type == ODEProblem
            # Don't need paramjac if not doing sensitivities, so save a little compile time by disabling it
            prob = ODEProblem(sys, nothing, tspan, sim; jac, paramjac, initializealg);
        elseif problem_type == ODEForwardSensitivityProblem
            # We ignore the `jac` settings for ODEForwardSensitivityProblem, as the constructor is overloaded to do the thing we need
            prob = ODEForwardSensitivityProblem(sys, nothing, tspan, sim; initializealg)
        else
            throw(ArgumentError("Unexpected problem_type $problem_type"))
        end
    end
    return prob
end

function prepare_problem!(sm::SimManager, params, abstol_dc, problem_type, mode, jac, paramjac)
    param_set = params === nothing ? Set{Symbol}() : sweepvars(params)
    problem_key = (param_set, problem_type, jac)
    if !haskey(sm.problems, problem_key)
        sm.problems[problem_key] = build_problem(sm, params, abstol_dc, problem_type, mode; jac, paramjac)
    end
    return sm.problems[problem_key]
end
function prepare_problem!(sm::SimManager, sp::SimParameterization; problem_type, jac::Bool = false, paramjac::Bool = false)
    prepare_problem!(sm, sp.params, sp.abstol_dc, problem_type, sp.mode, jac, paramjac)
end

function solver_alternatives(;
        successful_solver::Union{Symbol, Nothing} = nothing,
        preferred_solver::Union{Symbol, Nothing} = nothing,
        jac::Bool = false, problem_type = nothing,
    )
    solvers = Any[]
    prioritized_solvers = Any[]
    function insert_solver(solver)
        solver_sym = Symbol(solver_name(solver))
        solver_sym === successful_solver ? pushfirst!(prioritized_solvers, solver) :
        solver_sym === preferred_solver  ? push!(prioritized_solvers, solver) :
                                           push!(solvers, solver)
    end
    any_problem_type = problem_type === nothing
    ode_problem_type = problem_type == ODEProblem || problem_type == ODEForwardSensitivityProblem
    dae_problem_type = problem_type == DAEProblem
    # IDA
    if any_problem_type || dae_problem_type
        # `jac` doesn't influence IDA solver instantiation
        insert_solver(IDA())
    end
    # Rodas5P
    if any_problem_type || ode_problem_type
        insert_solver(Rodas5P(; autodiff = jac))
    end
    # Rosenbrock23
    if any_problem_type || ode_problem_type
        insert_solver(Rosenbrock23(; autodiff = jac))
    end
    # DFBDF (disabled until callback support completed)
    #if any_problem_type || dae_problem_type
    #    insert_solver(DFBDF(; autodiff = jac))
    #end
    # FBDF
    if any_problem_type || ode_problem_type
        insert_solver(FBDF(; autodiff = jac))
    end
    return [prioritized_solvers; solvers]
end

function problem_type_from_solver(solver)
    if solver isa IDA || solver isa DFBDF
        return DAEProblem
    elseif solver isa Rodas5P || solver isa Rosenbrock23 || solver isa FBDF
        return ODEProblem
    else
        error("unreachable?")
    end
end

function solver_name(solver)
    if solver isa IDA
        return "IDA"
    elseif solver isa DFBDF
        return "DFBDF"
    elseif solver isa FBDF
        return "FBDF"
    elseif solver isa Rodas5P
        return "Rodas5P"
    elseif solver isa Rosenbrock23
        return "Rosenbrock23"
    else
        # This should never happen
        return "Generic"
    end
end

function with_solver_choice(
        f::Function;
        successful_solver = nothing, preferred_solver = nothing,
        jac::Bool = false, problem_type = nothing,
    )
    errs = CompositeException()
    for solver in solver_alternatives(; successful_solver, preferred_solver, jac, problem_type)
        local ret
        try
            ret = f(solver)
        catch e
            @error("Error encountered while solving", exception=(e, catch_backtrace()))
            push!(errs, e)
            ret = nothing
        end

        # If we got a good solve, quit out now!
        if ret !== nothing
            return ret
        end
    end
    # If we never successfully solved, throw an error
    push!(errs, ArgumentError("Unable to solve problem with any known solver!"))
    throw(errs)
end

function cache_saved_signals(ss, sp, f)
    # Pre-cache all saved signals
    if !isempty(sp.saved_signals)
        @info("Caching saved signals")
        @log_timeit sp.sm.to "Caching" begin
            f(ss, ScopeRef.((ss,), sp.saved_signals))
        end
    end
end

# Set a conservative initial timestep
# X-ref: https://github.com/SciML/OrdinaryDiffEq.jl/issues/2152
extra_solver_args(sp, solver::FBDF) = (; dt=(sp.tspan[2] - sp.tspan[1])/10000.0)
extra_solver_args(sp, solver) = (;)

"""
    dc!(sm::SimManager, sp::SimParameterization)

Performs DC analysis upon the specified parameterization.  Returns a
[`SolutionSet`](@ref) object of the same shape as the parameterization.
"""
function CedarSim.dc!(sm::SimManager, sp::SimParameterization; force::Bool = false, timing::Bool = true, problem_type = nothing, jac::Bool = false, paramjac::Bool = false)
    if !haskey(sm.dc_solutions, sp) || force
        params = sp.params === nothing ? [DefaultSim(sm.circuit_func)] : collect(sp.params)
        s = length(params) == 1 ? "" : "s"
        @info("Solving $(length(sp.params)) DC simulation$s (abstol_dc=$(sp.abstol_dc))")
        @log_timeit sm.to "Solving" begin
            with_solver_choice(; successful_solver = sp.successful_solver[], preferred_solver = sp.preferred_solver, problem_type) do solver
                problem_type = problem_type_from_solver(solver)
                prob = prepare_problem!(sm, sp; problem_type, jac, paramjac)
                @log_timeit sm.to "DC ($(solver_name(solver)))" begin
                    sols = Array{AbstractODESolution}(undef, size(params))
                    Threads.@threads for idx in 1:length(params)
                        dc_prob = remake(prob; p=ParamSim(sm.circuit_func; mode=sp.mode, params[idx]...))
                        try
                            sols[idx] = init(dc_prob,
                                solver;
                                abstol=sp.abstol_dc,
                                initializealg=CedarDCOp(;abstol=sp.abstol_dc),
                            ).sol
                        catch e
                            if isa(e, LinearAlgebra.LAPACKException)
                                # Create fake solution object just to fail outside of the threaded loop
                                sols[idx] = SciMLBase.build_solution(
                                    dc_prob,
                                    solver,
                                    dc_prob.u0,
                                    0.0;
                                    retcode = ReturnCode.InitialFailure,
                                )
                            else
                                rethrow(e)
                            end
                        end
                    end
                    for (idx, sol) in enumerate(sols)
                        # Integrators sometimes return `Default` instead of `Success`
                        if sol.retcode ∉ (ReturnCode.Success, ReturnCode.Default)
                            return nothing
                        end

                        # Double-check residual, complain if it's too high
                        prob = sol.prob
                        tmp = similar(sol.u[1])
                        if problem_type == ODEProblem
                            # Only check algebraic equations for ODE formulation
                            residual_check_eqs = BitVector([iszero(prob.f.mass_matrix[i,i]) for i in 1:length(tmp)])
                            prob.f(tmp, sol.u[1], prob.p, sol.t[1])
                        else
                            residual_check_eqs = BitVector([true for _ in 1:length(tmp)])
                            prob.f(tmp, zero(sol.u[1]), sol.u[1], prob.p, sol.t[1])
                        end

                        residual = LinearAlgebra.norm(tmp[residual_check_eqs])
                        residual_limit = sp.abstol_dc*10.0
                        if residual > residual_limit
                            @warn("$(solver_name(solver)) returned `$(sol.retcode)`, but fails residual check", residual, residual_limit, string(prob.u0), params=param_summary(sol.prob.p), idx)
                        end
                    end
                    sm.dc_solutions[sp] = DCSolution(sols)
                end
            end
        end
        cache_saved_signals(sm.dc_solutions[sp], sp, cache_dc!)
        timing && print_timing(sm)
    end
    return sm.dc_solutions[sp]
end

"""
    ac!(sm::SimManager, sp::SimParameterization, frequencies::Vector{Float64})

Performs AC analysis upon the specified parameterization, evaluated at the given
frequencies.  See [`acdec`](@ref) for one convenient method of selecting frequencies
to evaluate at.  Returns a [`SolutionSet`](@ref) object of the same shape as the
parameterization.
"""
function CedarSim.ac!(sm::SimManager, sp::SimParameterization, ωs::Vector{Float64}; force::Bool = false, timing::Bool = true)
    # If `ϵω` is not already a parameter, create a new `sp` that has it:
    if sp.params === nothing
        params = ProductSweep(ϵω = [0.0])
    elseif !any(name == :ϵω for (name, val) in CedarSim.sweep_example(sp.params))
        params = ProductSweep(sp.params, ϵω = [0.0])
    else
        params = sp.params
    end
    ac_sp = SimParameterization(sp; params, mode=:ac)

    key = (sp, ωs)
    if !haskey(sm.ac_solutions, key) || force
        # In order to do an AC analysis, we need to get the DC operating point, so do that first,
        # but ask `dc!()` to compile the problem with the appropriate functions enabled
        ds = dc!(ac_sp, problem_type=ODEProblem, jac=true, paramjac=true, timing=false)

        # For each parameterization point, we will calculate the AC response
        @log_timeit sm.to "Solving" begin
            @log_timeit sm.to "AC" begin
                params = collect(params)

                acs = Array{ACSol}(undef, size(ds))
                Threads.@threads for idx in 1:length(acs)
                    acs[idx] = ACSol(ds.sols[idx])
                end

                sm.ac_solutions[key] = ACSolution(acs, ωs)
            end
        end

        cache_saved_signals(sm.ac_solutions[key], sp, cache_ac!)
        timing && print_timing(sm)
    end
    return sm.ac_solutions[key]
end

"""
    noise!(sm::SimManager, sp::SimParameterization, frequencies::Vector{Float64})

Performs noise analysis upon the specified parameterization, evaluated at the given
frequencies.  See [`acdec`](@ref) for one convenient method of selecting frequencies
to evaluate at.  Returns a [`SolutionSet`](@ref) object of the same shape as the
parameterization.
"""
function CedarSim.noise!(sm::SimManager, sp::SimParameterization, ωs::Vector{Float64}; force::Bool = false, timing::Bool = true)
    ac_sp = SimParameterization(sp; mode=:ac)

    key = (sp, ωs)
    if !haskey(sm.noise_solutions, key) || force
        # In order to do an AC analysis, we need to get the DC operating point, so do that first,
        # but ask `dc!()` to compile the problem with the appropriate functions enabled
        ds = dc!(ac_sp, problem_type=ODEProblem, jac=true, timing=false)

        # For each parameterization point, we will calculate the AC response
        @log_timeit sm.to "Solving" begin
            @log_timeit sm.to "AC" begin

                acs = Array{NoiseSol}(undef, size(ds))
                Threads.@threads for idx in 1:length(acs)
                    acs[idx] = NoiseSol(ds.sols[idx])
                end

                sm.noise_solutions[key] = NoiseSolution(acs, ωs)
            end
        end

        cache_saved_signals(sm.noise_solutions[key], sp, cache_noise!)
        timing && print_timing(sm)
    end
    return sm.noise_solutions[key]
end

"""
    warmup_problem!(prob)

Because we have JITOpaqueClosures sitting around, we need to ensure that
the specialization for our problems is properly cached before we start
multithreading `solve()` calls that would all hit the JIT cache.
"""
function warmup_problem!(prob)
    if !isnothing(prob.u0)
        u0 = prob.u0
        du0 = 0 * u0
        tmp = similar(prob.u0)
    else
        u0 = nothing
        du0 = nothing
        tmp = nothing
    end
    if isa(prob, DAEProblem)
        prob.f(tmp, du0, u0, prob.p, 0.0)
    else
        prob.f(tmp, u0, prob.p, 0.0)
    end
end

function add_linearizer(prob, ils; kwargs...)
    if prob isa ODEProblem
        differential_vars = BitVector([!iszero(prob.f.mass_matrix[i,i]) for i=1:size(prob.f.mass_matrix,1)])
        cb = LinearizingSavingCallback(ils; interpolate_mask = differential_vars)
    elseif prob isa DAEProblem
        cb = LinearizingSavingCallback(ils)
    else @assert false end
    callback_set = get_transformed_sys(prob).state.callback_func()
    return remake(prob; callback = CallbackSet(cb, callback_set), kwargs...)
end

# Return a `remake()` function that adds an ils onto each prob for ensembles
# We set `num_derivatives=1` here so that we capture `u` and `du`, but you
# could set it to `2` if you need `ddu` as well.
function linearizer_adding_remake(sp, params, ilss; num_derivatives=1)
    return (prob,i,repeat) -> begin
        ilss[i] = IndependentlyLinearizedSolution(prob, num_derivatives)
        prob = add_linearizer(
            prob,
            ilss[i],
            p=ParamSim(sp.sm.circuit_func; mode=sp.mode, params[i]...),
            tspan=sp.tspan,
        )
        return prob
    end
end

"""
    tran!(sm::SimManager, sp::SimParameterization)

Performs Transient analysis upon the specified parameterization.  Returns a
[`SolutionSet`](@ref) object of the same shape as the parameterization.
"""
function CedarSim.tran!(sm::SimManager, sp::SimParameterization; force::Bool = false, timing::Bool = true)
    if !haskey(sm.tran_solutions, sp) || force
        params = sp.params === nothing ? [DefaultSim(sm.circuit_func)] : collect(sp.params)
        s = length(params) == 1 ? "" : "s"
        @info("Solving $(length(params)) transient simulation$s (abstol_dc=$(sp.abstol_dc), abstol_tran=$(sp.abstol_tran), reltol_tran=$(sp.reltol_tran))")
        @log_timeit sm.to "Solving" begin
            with_solver_choice(; successful_solver = sp.successful_solver[], preferred_solver = sp.preferred_solver) do solver
                ilss = Array{IndependentlyLinearizedSolution}(undef, size(params))
                problem_type = problem_type_from_solver(solver)
                prob = prepare_problem!(sm, sp; problem_type)
                warmup_problem!(prob)
                ensembleprob = EnsembleProblem(prob; prob_func=linearizer_adding_remake(sp, params, ilss), safetycopy=false)
                @log_timeit sm.to "Transient ($(solver_name(solver)))" begin
                    esol = solve(
                        ensembleprob,
                        solver,
                        EnsembleThreads();
                        trajectories=length(params),
                        maxiters=sp.maxiters,
                        initializealg=CedarTranOp(;abstol=sp.abstol_dc),
                        abstol=sp.abstol_tran,
                        reltol=sp.reltol_tran,
                        progress=true,
                        progress_steps=sp.progress_steps,
                        save_on=true,
                        # We still save the starting point, so that DC analysis can run with this
                        save_start=true,
                        save_end=true,
                        extra_solver_args(sp, solver)...
                    )
                    @debug esol.stats
                    sols = reshape(esol.u, size(params))
                    if any(sol.retcode != ReturnCode.Success for sol in sols)
                        return nothing
                    end
                    sp.successful_solver[] = Symbol(solver_name(solver))
                    sm.tran_solutions[sp] = TranSolution(sols, ilss)
                end
            end
        end

        # Pre-cache all saved signals
        cache_saved_signals(sm.tran_solutions[sp], sp, cache_tran!)
        timing && print_timing(sm)
    end
    return sm.tran_solutions[sp]
end

"""
    sensitivities!(sm::SimManager, sp::SimParameterization)

Performs Sensitivity analysis upon the specified parameterization.  Returns a
[`SolutionSet`](@ref) object of the same shape as the parameterization.
"""
function sensitivities!(sm::SimManager, sp::SimParameterization; force::Bool = false, timing::Bool = true)
    problem_type = ODEForwardSensitivityProblem
    if !haskey(sm.sensitivities, sp) || force
        sprob = prepare_problem!(sp.sm, sp; problem_type)

        #signalref_syms = [s.name for s in sp.saved_signals if s isa Probe]
        if sp.params === nothing
            throw(ArgumentError("Must provide a parameterization to calculate sensitivities!"))
        end
        params = collect(sp.params)

        s = length(params) == 1 ? "" : "s"
        @info("Solving $(length(params)) sensitivity simulation$s (abstol_dc=$(sp.abstol_dc), abstol_tran=$(sp.abstol_tran), reltol_tran=$(sp.reltol_tran)))")
        @log_timeit sm.to "Solving" begin
            with_solver_choice(; successful_solver = sp.successful_solver[], preferred_solver = sp.preferred_solver, problem_type) do solver
                ilss = Array{IndependentlyLinearizedSolution}(undef, size(params))
                ensembleprob = EnsembleProblem(
                    sprob;
                    prob_func=linearizer_adding_remake(sp, params, ilss),
                    safetycopy=false,
                )
                @log_timeit sm.to "Transient Sensitivity ($(solver_name(solver)))" begin
                    esol = solve(
                        ensembleprob,
                        solver,
                        EnsembleThreads();
                        trajectories=length(params),
                        maxiters=sp.maxiters,
                        initializealg=CedarTranOp(;abstol=sp.abstol_dc),
                        abstol=sp.abstol_tran,
                        reltol=sp.reltol_tran,
                        progress=true,
                        progress_steps=sp.progress_steps,
                        save_on=true,  # Needed because measure_senstivity code doesn't support ilss
                        # We still save the start so that DC analysis can still run with this
                        save_start=true,
                        save_end=true,  # Needed because measure_senstivity code doesn't support ilss
                        extra_solver_args(sp, solver)...,
                    )
                    sols = reshape(esol.u, size(params))
                    if any(sol.retcode != ReturnCode.Success for sol in sols)
                        return nothing
                    end
                    sm.sensitivities[sp] = SensitivitySolution(sols, ilss)
                end
            end
        end

        cache_saved_signals(sm.sensitivities[sp], sp, cache_sensitivity!)
        timing && print_timing(sm)
    end
    return sm.sensitivities[sp]
end

"""
    load_surrogate!(surrogate_path::String, sm::SimManager, control)

Loads a surrogate located at surrogate_path and associates with a SimManager
Returns a SurroagateSimManager which can perform tran! using the surrogate.

Requires loading Surrogatize
"""
function load_surrogate(args...)
    throw(ErrorException("Load Surrogatize to use this function"))
end
