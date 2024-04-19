module CedarEDASurrogatizeExt
using CedarEDA
using CedarEDA: Serialization, OrdinaryDiffEq, LinearizingSavingCallback, AbstractSimManager, SimParameterization
using CedarEDA: @log_timeit, IndependentlyLinearizedSolution, ILSSlice, problem_type_from_solver, CedarSim, extra_solver_args
using CedarEDA: TranSolution, print_timing, TimerOutputs, SciMLBase, LinearAlgebra, Serialization, Sundials
using TimerOutputs: @timeit
using Surrogatize: Layer, DataGeneration, PreProcessing
using OrdinaryDiffEq: solve, Tsit5
#using Layer: Flux
using Serialization, OrdinaryDiffEq
using CedarWaves: display_value
using ProgressMeter: @showprogress, next!

using SciMLBase: SymbolicIndexingInterface

struct CedarSurrogateSystem{T, C, PZ, SZ, CZ}
    W::Matrix{Float64}
    Win::Matrix{Float64}
    tau::Float64
    r0::Vector{Float64}
    decoder::T
    ctrl::C
    p_zscore::PZ
    state_zscore::SZ
    ctrl_zscore::CZ
    state_labels::Vector{Symbol}
    param_labels::Vector{Symbol}
    default_params::Vector{Float64}
    params_lb::Vector{Float64}
    params_ub::Vector{Float64}
end
function Base.show(io::IO, s::CedarSurrogateSystem)
    println(io, "CedarSurrogateSystem, trained on parameters:")
    for (name, lb, ub) in zip(s.param_labels, s.params_lb, s.params_ub)
        println(io, "   - $(name) ($(display_value(lb)) .. $(display_value(ub)))")
    end
end

@fastmath function CedarSurrogateF(du, u, p, t)
    W, Win, decoder, p, u0, τ, ctrl, iph = p
    # state_input = t == 0.0 ? p[4] : p[2](u)
    state_input = decoder(vcat(u, u0, p))
    inputs = vcat(state_input, p, u0, iph*ctrl(t))
    # inputs = vcat(p[2](vcat(u[RSIZE+1:end],p[5])),p[3](t),p[4],p[5],u[1:RSIZE])
    du .= inv(τ).*(tanh.(W*u .+ Win*inputs) .- u)
end

function OrdinaryDiffEq.ODEProblem(sys::CedarSurrogateSystem, _u0, tspan, _p; kwargs...)
    (;W, Win, decoder, p_zscore, state_zscore, tau, ctrl, ctrl_zscore, param_labels) = sys
    iphind = findfirst(==(:Iph), param_labels)
    p = (W, Win, decoder, p_zscore(_p), state_zscore(_u0), tau, t->ctrl_zscore(ctrl(t)), _p[iphind])
    get_result = genresult(sys)
    odefun =  OrdinaryDiffEq.ODEFunction(CedarSurrogateF; sys=sys, observed=(sym, args...) -> get_result)
    pred_prob = OrdinaryDiffEq.ODEProblem(odefun, sys.r0, tspan, p)
    return pred_prob
end
struct Result
end
SymbolicIndexingInterface.symbolic_type(::Result) = SymbolicIndexingInterface.ScalarSymbolic()
SymbolicIndexingInterface.is_variable(sys::CedarSurrogateSystem, sym) = false
SymbolicIndexingInterface.variable_index(::CedarSurrogateSystem, sym) = nothing
SymbolicIndexingInterface.is_parameter(sys::CedarSurrogateSystem, sym) = false
SymbolicIndexingInterface.parameter_index(::CedarSurrogateSystem, sym) = nothing
SymbolicIndexingInterface.is_independent_variable(sys::CedarSurrogateSystem, sym) = false
SymbolicIndexingInterface.is_time_dependent(sys::CedarSurrogateSystem) = true
SymbolicIndexingInterface.constant_structure(::CedarSurrogateSystem) = true
SymbolicIndexingInterface.is_observed(::CedarSurrogateSystem, sym) = sym == Result()
SymbolicIndexingInterface.all_symbols(::CedarSurrogateSystem) = [Result()]
function genresult(sys)
    function get_result(u, p, t)
        W, Win, decoder, _p, u0, ctrl = p
        only(PreProcessing.denormalize(sys.state_zscore, decoder(vcat(u, u0, _p))))
    end
end
function SymbolicIndexingInterface.observed(::CedarSurrogateSystem, sym)
    @assert sym == Result()
    get_result
end
struct SurrogateManager{SR, SM} <: AbstractSimManager
    surr::SR
    sm::SM
end

OrdinaryDiffEq.ODEProblem(s::SurrogateManager, args...;  kwargs...) = OrdinaryDiffEq.ODEProblem(s.surr, args...; kwargs...)
function Base.show(io::IO, s::SurrogateManager)
    show(io, s.surr)
    print(io, "for sim ")
    show(io, s.sm)
end

function CedarEDA.load_surrogate(surrogate_file::AbstractString, sim::SimManager)
    return SurrogateManager(deserialize(surrogate_file), sim)
end

CedarEDA.prepare_problem!(s::SurrogateManager, args...; kwargs...) = CedarEDA.prepare_problem!(s.sm, args...; kwargs...)

function CedarEDA.tran!(s::SurrogateManager, sp::SimParameterization; force::Bool = false, timing::Bool = true)
    (;sm, surr) = s
    if !haskey(sm.tran_solutions, sp) || force
        params = sp.params === nothing ? [DefaultSim(sm.circuit_func)] : collect(sp.params)
        sim = length(params) == 1 ? "" : "s"
        @info("Simulating (via surrogate) $(length(params)) transient simulation$sim (abstol_dc=$(sp.abstol_dc), abstol_tran=$(sp.abstol_tran), reltol_tran=$(sp.reltol_tran))")
        @log_timeit sm.to "Solving" begin
            prob = CedarEDA.prepare_problem!(sm, sp; problem_type=DAEProblem)
            CedarEDA.warmup_problem!(prob)
            u0 = prob.u0 === nothing ? zeros(length(surr.state_labels)) : prob.u0
            surrprob = ODEProblem(surr, u0, sp.tspan, surr.default_params, abstol = 1e-8, reltol = 1e-8)
            @log_timeit sm.to "Transient (surrogate)" begin
                sols = Array{SciMLBase.DiffEqArray}(undef, size(params))
                ilss = Array{IndependentlyLinearizedSolution}(undef, size(params))
                sym = getproperty.((CedarSim.get_sys(prob.f),), surr.state_labels)
                init_sol = Array{SciMLBase.AbstractODESolution}(undef, size(params))
                @showprogress Threads.@threads for idx in 1:length(params)

                    dc_prob = remake(prob; p=ParamSim(sm.circuit_func; mode=sp.mode, params[idx]...))
                    init_sol[idx] = isol = init(dc_prob, Sundials.IDA();
                        abstol=sp.abstol_dc, initializealg=CedarTranOp(;abstol=sp.abstol_dc)
                    ).sol
                    orderedp = Float64[]
                    for (name, default_value, lb, ub) in zip(surr.param_labels, surr.default_params, surr.params_lb, surr.params_ub)
                        value = get(isol.prob.p.params, name, default_value)
                        if value < lb || value > ub
                            @error "param $name has value $value outside of trained range for surrogate ($(display_value(lb)), $(display_value(ub)))"
                        end
                        push!(orderedp, value)
                    end
                    ilss[idx] = IndependentlyLinearizedSolution(surrprob, #= num_derivatives =# 1)
                    surrprob = remake(surrprob;
                        p = (
                             surr.W,
                             surr.Win,
                             surr.decoder,
                             surr.p_zscore(orderedp),
                             surr.state_zscore(only(isol[sym])),
                             surr.tau,
                             surr.ctrl,
                             isol.prob.p.params[:Iph]
                        ),
                        callback = LinearizingSavingCallback(ilss[idx]),
                    )
                    sol = solve(surrprob, Tsit5())
                    # use `t` sample points from ILSS
                    slice = ILSSlice(ilss[idx], [1])
                    t = getindex.(slice, 1)
                    result = sol(t, idxs=Result())
                    sols[idx] = result
                end
                
                ts = SolutionSet(:Surrogate, size(sols))
                CedarEDA.Parameters!(ts, init_sol)
                function signal_ctor(idx)
                    return Signal(sols[idx].t, sols[idx].u)
                end
                ts.outputs[:tran] = CedarEDA.TabCompleter(
                    "Transient Signals",
                    surr.state_labels;
                    leaf = (k, ref) -> signal_ctor.(CartesianIndices(sols)),
                    keys = x -> isnothing(x) ? nothing : x,
                    getindex = Returns(nothing),
                )
                ts.shaped_metadata[:sols] = init_sol
                ts.shaped_metadata[:ilss] = ilss
                sm.tran_solutions[sp] = ts
            end
        end
        timing && print_timing(sm)
    end
    return sm.tran_solutions[sp]
end

end
