using DAECompiler: StructuralAnalysisResult
using SciMLSensitivity

"""
    SimParameterization

General struct representing the parameterization of a simulation; which parameters
are swept over, the tolerance of the simulation, etc...  Changing these values will
generally require the problem to be re-compiled.
"""
struct SimParameterization
    sm::AbstractSimManager
    params::Union{Nothing,CedarSim.SweepLike}
    tspan::Tuple{Float64, Float64}
    abstol_dc::Float64
    abstol_tran::Float64
    reltol_tran::Float64
    maxiters::Int64
    progress_steps::Int64
    mode::Symbol

    saved_signals::Vector{Probe}
    trchecks::Vector{<:AbstractCheck}
    dcchecks::Vector{<:AbstractCheck}
    acchecks::Vector{<:AbstractCheck}
    noisechecks::Vector{<:AbstractCheck}
    probes::TabCompleter
    preferred_solver::Union{Symbol, Nothing}
    successful_solver::Base.RefValue{Union{Symbol, Nothing}}

    function SimParameterization(sm::AbstractSimManager;
                                 params = nothing,
                                 tspan = (0.0, 1.0),
                                 abstol_dc = 1e-14,
                                 abstol_tran = 1e-5,
                                 reltol_tran = 1e-3,
                                 maxiters = 1e7,
                                 progress_steps = 1000*length(something(params, (nothing,))),
                                 mode = :tran,
                                 saved_signals = Probe[],
                                 trchecks = AbstractCheck[],
                                 dcchecks = AbstractCheck[],
                                 acchecks = AbstractCheck[],
                                 noisechecks = AbstractCheck[],
                                 preferred_solver = nothing)
        # Just immediately compile it so we can get nice tab-completion on `signals`
        problem_type = problem_type_from_solver(first(solver_alternatives(; successful_solver=nothing, preferred_solver)))
        prob = prepare_problem!(sm, params, abstol_dc, problem_type, mode, false, false)
        probes = ProbeSelector(prob.f.sys.state.sys)
        return new(
            sm,
            params,
            tspan,
            abstol_dc,
            abstol_tran,
            reltol_tran,
            maxiters,
            progress_steps,
            mode,
            saved_signals,
            trchecks,
            dcchecks,
            acchecks,
            noisechecks,
            probes,
            preferred_solver,
            Ref{Union{Symbol, Nothing}}(nothing),
        )
    end
end
function SimParameterization(sp::SimParameterization;
                             params=sp.params,
                             tspan=sp.tspan,
                             abstol_dc=sp.abstol_dc,
                             abstol_tran=sp.abstol_tran,
                             reltol_tran=sp.reltol_tran,
                             maxiters=sp.maxiters,
                             progress_steps=sp.progress_steps,
                             mode=sp.mode,
                             saved_signals=sp.saved_signals,
                             trchecks=sp.trchecks,
                             dcchecks=sp.dcchecks,
                             acchecks=sp.acchecks,
                             noisechecks=sp.acchecks,
                             preferred_solver=sp.preferred_solver)
    return SimParameterization(sp.sm;
        params,
        tspan,
        abstol_dc,
        abstol_tran,
        reltol_tran,
        maxiters,
        progress_steps,
        mode,
        saved_signals,
        trchecks,
        dcchecks,
        acchecks,
        noisechecks,
        preferred_solver,
    )
end

"""
    sweepvars(sp::SimParameterization)

Return a `Set{Symbol}` of the parameters that are swept over in the given
`SimParameterization` object.
"""
CedarSim.sweepvars(sp::SimParameterization) = sp.params === nothing ? Set{Symbol}() : sweepvars(sp.params)
function Base.show(io::IO, sp::SimParameterization)
    if sp.params === nothing
        println(io, "SimParameterization with default parameterization")
    else
        println(io, "SimParameterization with parameterization:")
        param_ranges = CedarSim.find_param_ranges(sp.params)
        max_name_len = maximum(length.(string.(keys(param_ranges))))
        pad(name) = string(name, " "^(max_name_len - length(name)))
        for name in sort(collect(keys(param_ranges)))
            pmin, pmax, plen = param_ranges[name]
            if plen==1
                println(io, " - $(pad(string(name))) = $(CedarWaves.display_value(pmin))")
            else
                println(io, " - $(pad(string(name))) ($plen values: $(CedarWaves.display_value(pmin)) .. $(CedarWaves.display_value(pmax)))")
            end
        end
        print(io, "Total: $(length(sp.params)) simulations to sweep over.")
    end
end

function build_problem(sp::SimParameterization; problem_type=sp.problem_type, mode=sp.mode, kwargs...)
    return build_problem(sp.sm, sp.params, sp.abstol_dc, problem_type, mode; kwargs...)
end

"""
    set_saved_signals!(sp::SimParameterization, saved_signals::Vector{Probe})

Defines the set of signals that are plotted via [`explore()`](@ref) or saved to
`.csv` via [`export_csvs()`](@ref) by default.  Signals can always be extracted
from [`SolutionSet`](@ref) objects, this usage is merely a convenience for
marking certain signals that will be commonly plotted or exported.
"""
function set_saved_signals!(sp::SimParameterization, saved_signals::Vector{<:Probe})
    empty!(sp.saved_signals)
    append!(sp.saved_signals, unique(saved_signals))
end

function set_checks!(sp::SimParameterization, tran::Vector{<:AbstractCheck})
    empty!(sp.trchecks)
    append!(sp.trchecks, unique(tran))
end

"""
    set_checks!(sp::SimParameterization; tran, dc, ac)

Set the set of checks that will be applied to the given `SimParameterization`
when `check()` is called.  These checks are visualized within `explore()`
output.
"""
function set_checks!(sp::SimParameterization;
                     tran::Vector{<:AbstractCheck}=AbstractCheck[],
                     dc::Vector{<:AbstractCheck}=AbstractCheck[],
                     ac::Vector{<:AbstractCheck}=AbstractCheck[],
                     noise::Vector{<:AbstractCheck}=AbstractCheck[])
    if !isempty(tran)
        empty!(sp.trchecks)
        append!(sp.trchecks, unique(tran))
    end
    if !isempty(dc)
        empty!(sp.dcchecks)
        append!(sp.dcchecks, unique(dc))
    end
    if !isempty(ac)
        empty!(sp.acchecks)
        append!(sp.acchecks, unique(ac))
    end
    if !isempty(noise)
        empty!(sp.acchecks)
        append!(sp.acchecks, unique(noise))
    end
end

# Passthrough definitions
CedarSim.dc!(sp::SimParameterization; kwargs...) = CedarSim.dc!(sp.sm, sp; kwargs...)
CedarSim.tran!(sp::SimParameterization; kwargs...) = CedarSim.tran!(sp.sm, sp; kwargs...)
CedarSim.ac!(sp::SimParameterization, ωs::Vector{Float64}; kwargs...) = CedarSim.ac!(sp.sm, sp, ωs; kwargs...)
CedarSim.noise!(sp::SimParameterization, ωs::Vector{Float64}; kwargs...) = CedarSim.noise!(sp.sm, sp, ωs; kwargs...)
sensitivities!(sp::SimParameterization; kwargs...) = sensitivities!(sp.sm, sp; kwargs...)

using DataFrames, DataFrames.PrettyTables
function param_summary(sim::ParamSim)
    str_vals = String[]
    for (name, val) in pairs(sim.params)
        push!(str_vals, @sprintf("%s=%.2e", name, val))
    end
    return join(str_vals, ", ")
end
function param_summary(sim::DefaultSim)
    return "default"
end
function param_summary(sol::AbstractODESolution)
    return param_summary(sol.prob.p)
end

# TODO: We should have a dedicated data type for holding check results
# that shows as a `"✔️"`, rather than just an `AnsiTextCell`.  We'll get there.
function is_success(cell::PrettyTables.AnsiTextCell)
    return contains(cell.string, "✔️")
end
function is_success(row::DataFrameRow)
    for cell in row
        if isa(cell, PrettyTables.AnsiTextCell) && !is_success(cell)
            return false
        end
    end
    return true
end

function check_(sp, ts, checks)
    if isempty(checks)
        return DataFrame()
    end

    col_names = [get_name(check) for check in checks]
    cols_by_thread = [Dict(
        [n => PrettyTables.AnsiTextCell[] for n in col_names]...,
        "parameterization" => String[],
    ) for _ in 1:Threads.nthreads()]

    Threads.@threads for sol_idx in 1:length(ts.sols)
        cols = cols_by_thread[Threads.threadid()]
        for (ch_idx, check) in enumerate(checks)
            r = apply(ts, check, [sol_idx])
            mark = satisfied(r) ? "✔️" : "❌"
            cell = PrettyTables.AnsiTextCell(string(
                LinkProvider.Link(() -> display(plot_check(sp, ts, [sol_idx], check)), mark),
            ))
            push!(cols[col_names[ch_idx]], cell)
        end

        push!(cols["parameterization"], param_summary(ts.sols[sol_idx]))
    end

    df = DataFrame(cols_by_thread[1])
    for cols in cols_by_thread[2:end]
        append!(df, cols)
    end
    return df
end
check(sp::SimParameterization) = check(sp, tran!(sp))
function check(sp::SimParameterization, ts::TransientSolutionType)
    check_(sp, ts, sp.trchecks)
end

function check(sp::SimParameterization, ts::ACSolutionType)
    check_(sp, ts, sp.acchecks)
end

function check(sp::SimParameterization, ts::DCSolutionType)
    check_(sp, ts, sp.dcchecks)
end


using CSV
export export_csv, export_csvs
"""
    export_csv(file::String, sig::AbstractSignal)

Export a single signal to `.csv`, saving time values as the first column `t`,
and the amplitude values as the second column `y`.
"""
function export_csv(file::String, sig::AbstractSignal)
    data = (;
        :t => xvals(sig),
        :y => yvals(sig),
    )
    return CSV.write(file, data)
end

"""
    export_csvs(dir::String, ss::SolutionSet, probe)

Given a `SolutionSet` and `probe`, export the signal referred to by that `probe`
for all solutions contained within that `SolutionSet`, naming each individual
file based on its index within the `SolutionSet`.
"""
function export_csvs(dir::String, ss::SolutionSet, probe::Union{Probe,ScopeRef})
    mkpath(dir)
    sigs = get_tran(ss, probe)
    for idx in 1:length(sigs)
        export_csv(joinpath(dir, string(probe, "[$(idx)].csv")), sigs[idx])
    end
end

"""
    export_csvs(dir::String, sp::SimParameterization)

Perform transient analysis on the given `SimParameterization`, then export all
saved signals (set via [`set_saved_signals!()`](@ref)) to `.csv`, across all
parameterization points, into the given output directory.
"""
function export_csvs(dir::String, sp::SimParameterization)
    ts = tran!(sp)
    for probe in sp.saved_signals
        export_csvs(dir, ts, probe)
    end
end
