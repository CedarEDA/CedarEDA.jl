using CedarSim
using CedarWaves
using WGLMakie
using StructArrays
using WGLMakie.Makie.Observables
using Statistics
import WGLMakie.Makie: extract_color, choose_scalar

# Default to dark theme
#WGLMakie.set_theme!(theme_dark())

@recipe(SignalPlot2) do scene
    # errorcolor default based on background lightness
    errc = lift(theme(scene, :backgroundcolor), get(theme(scene), :errorcolor, nothing)) do bgc, errc
        bgc = Makie.Colors.parse(Makie.Colors.Colorant, bgc)
        l = convert(Makie.Colors.HSL, bgc).l
        default = if l > .5
            Makie.RGBAf(1, 0, 0, .2)
        else
            Makie.RGBAf(1, 0, 0, .8)
        end
        something(errc, default)
    end

    Attributes(
        color = theme(scene, :linecolor),
        colormap = theme(scene, :colormap),
        # https://github.com/MakieOrg/Makie.jl/pull/3046
        xgridcolor = get(something(get(theme(scene), :Axis, nothing), Attributes()), :xgridcolor, RGBAf(0, 0, 0, 0.12)),
        colorrange = Makie.automatic,
        markersize = 25,
        errorcolor = errc,
        cycle = [:color],
    )
end



function Makie.data_limits(plt::SignalPlot2{<:Tuple{DyCheckResult}})
    return Rect3f()
end
function Makie.data_limits(plt::SignalPlot2{<:Tuple{YCheckResult}})
    return Rect3f()
end
function Makie.data_limits(plt::SignalPlot2{<:Tuple{DxCheckResult}})
    return Rect3f()
end


function Makie.plot!(plt::SignalPlot2{<:Tuple{CedarWaves.AbstractSignal}})
    s = plt[1]
    xy = lift(s->StructArray{Point2{Float64}}((xvals(s), yvals(s))), s)
    lines!(plt, xy,
        color = plt.color,
        colormap = plt.colormap,
        colorrange = plt.colorrange,
        linewidth = 2,
    )
end

function points(m::CedarWaves.CrossMeasure)
    [Point2(m.x, m.yth.value)]
end

function points(m::CedarWaves.OnePointMeasure)
    [Point2(m.x, m.y)]
end

function points(m::CedarWaves.TwoPointMeasure)
    Iterators.flatmap(points, [m.pt1, m.pt2]) |> collect
end

function points(m::CedarWaves.DerivedMeasure)
    Iterators.flatmap(points, m.measures) |> collect
end

function markers(m::CedarWaves.CrossMeasure)
    [m.yth isa rising ? :utriangle : :dtriangle]
end

function markers(m::CedarWaves.YMeasure)
    [:diamond]
end

function markers(m::CedarWaves.TwoPointMeasure)
    Iterators.flatmap(markers, [m.pt1, m.pt2]) |> collect
end

function markers(m::CedarWaves.DerivedMeasure)
    Iterators.flatmap(markers, m.measures) |> collect
end

function get_label(s, probe::Probe)
    string(probe)
end

get_label(m::CedarWaves.AbstractMeasure) = "$(uppercasefirst(m.name))=$(CedarWaves.display_value(m))"
get_label(m::Union{DxCheckResult,DyCheckResult}, sr::FunctionCheck) = get_label(m.meas)
get_label(m::YCheckResult, sr::FunctionCheck) = get_label(m.meas)

function get_label(ms::Vector, sr::Union{FunctionMeasure,FunctionCheck})
    join([get_label(m, sr) for m in ms], ", ")
end

function measureplot(plt, m, violation=Observable(false))
    cross = lift(points, m)
    line = lift(a->map(c->c[2], a), cross)
    marker = lift(markers, m)
    glowwidth = lift(v->v ? 5 : 0, violation)

    hlines!(plt, line, linestyle=:dot, color=plt.xgridcolor) # this should really be a minor tick
    scatter!(plt, cross, marker=marker,
        markersize=plt.markersize,
        color = plt.color,
        colormap = plt.colormap,
        colorrange = plt.colorrange,
        glowwidth = glowwidth,
        glowcolor = plt.errorcolor,
    )
end
#function Makie.plot!(plt::SignalPlot2{<:Tuple{CedarWaves.AbstractMeasure}})
#    m = plt[1]
#    measureplot(plt, m)
#end

function Makie.plot!(plt::SignalPlot2{<:Tuple{DxCheckResult}})
    m = plt[1]
    xmin = lift(m->[m.meas.pt1.x + minimum(m.domain)], m)
    xmax = lift(m->[m.meas.pt1.x + maximum(m.domain)], m)
    yval = lift(m->[Float64(m.meas.pt2.yth.value)], m)
    xval = lift(m->[Float64(m.meas.pt2.x)], m)
    violation = lift(m->!(m.meas.pt1.x + minimum(m.domain) <= m.meas.pt2.x <=
                            m.meas.pt1.x + maximum(m.domain)), m)

    measureplot(plt, lift(m->m.meas.pt1, m))
    measureplot(plt, lift(m->m.meas.pt2, m), violation)
    rangebars!(plt, yval, xmin, xmax,
        color = plt.color,
        whiskerwidth = plt.markersize,
        direction = :x,
    )

    # Add `!` over our marker if we're in a violation
    text!(plt, xval, yval, text="!",
        visible=violation,
        color=:white,
        align=(:center, :center),
        font = :bold,
        fontsize = lift(s->s*0.6, plt.markersize),
    )

    vspan!(plt, xmax, xval;
        visible=violation,
        color=RGBAf(1,0,0,0.2),
        # Work around annoying bug where this causes zooming problems
        #ymin=0.1,
        #ymax=.9,
    )
    plt
end

function Makie.plot!(plt::SignalPlot2{<:Tuple{DyCheckResult}})
    m = plt[1]
    violation = lift(!satisfied, m)
    max = lift(m->maximum(m.meas.signal), m)

    ymin = lift(m->[m.meas.pt1.yth.value+minimum(m.domain)], m)
    ymax = lift(m->[m.meas.pt1.yth.value+maximum(m.domain)], m)
    xval = lift(m->[m.x], max)
    yval = lift(m->[m.y], max)

    #measureplot(plt, lift(m->m.meas, m))
    measureplot(plt, max, violation)

    rangebars!(plt, xval, ymin, ymax,
    color = plt.color,
    whiskerwidth = plt.markersize,
    direction = :y)
    text!(plt, xval, yval, text="!",
        visible=violation,
        color=:white,
        align=(:center, :center),
        font = :bold,
        fontsize = lift(s->s*0.6, plt.markersize),
    )
    hspan!(plt, ymax, yval; visible=violation, color=RGBAf(1,0,0,0.2))
end

function Makie.plot!(plt::SignalPlot2{<:Tuple{YCheckResult}})
    m = plt[1]
    Core.eval(Main, :(plt = $(plt)))
    violation = lift(!satisfied, m)
    max = lift(m->maximum(m.meas.signal), m)

    ymin = lift(m->[minimum(m.domain)], m)
    ymax = lift(m->[maximum(m.domain)], m)
    xval = lift(m->[m.x], max)
    yval = lift(m->[m.y], max)

    measureplot(plt, max, violation)

    rangebars!(plt, xval, ymin, ymax,
    color = plt.color,
    whiskerwidth = plt.markersize,
    direction = :y)
    text!(plt, xval, yval, text="!",
        visible=violation,
        color=:white,
        align=(:center, :center),
        font = :bold,
        fontsize = lift(s->s*0.6, plt.markersize),
    )
    hspan!(plt, ymax, yval; visible=violation, color=RGBAf(1,0,0,0.2))
end

function Makie.legendelements(plot::SignalPlot2{<:Tuple{DxCheckResult}}, legend)
    m = plot[1]
    violation = lift(!satisfied, m)
    glowwidth = lift(v->v ? 3 : 0, violation)
    exclcolor = lift(v->v ? RGBAf(1,1,1,1) : RGBAf(1,1,1,0), violation)
    LegendElement[
        MarkerElement(
            color = extract_color(plot, legend.markercolor),
            marker = lift(m->m.meas.pt2.yth isa rising ? :utriangle : :dtriangle, plot[1]),
            markersize = choose_scalar(plot.markersize, legend.markersize),
            strokewidth = glowwidth, # glow doesn't seem to work
            strokecolor = plot.errorcolor,
        ),
        MarkerElement(
            color = exclcolor,
            marker = '!',
            markersize = lift(s->s*0.6, choose_scalar(plot.markersize, legend.markersize)),
            font = :bold, # this doesn't seem to work
        )
    ]
end

function Makie.legendelements(plot::SignalPlot2{<:Tuple{DyCheckResult}}, legend)
    m = plot[1]
    violation = lift(m->m.meas.height ∉ m.domain, m)
    glowwidth = lift(v->v ? 3 : 0, violation)
    exclcolor = lift(v->v ? RGBAf(1,1,1,1) : RGBAf(1,1,1,0), violation)
    LegendElement[
        MarkerElement(
            color = extract_color(plot, legend.markercolor),
            marker = :diamond,
            markersize = choose_scalar(plot.markersize, legend.markersize),
            strokewidth = glowwidth, # glow doesn't seem to work
            strokecolor = plot.errorcolor,
        ),
        MarkerElement(
            color = exclcolor,
            marker = '!',
            markersize = lift(s->s*0.6, choose_scalar(plot.markersize, legend.markersize)),
            font = :bold, # this doesn't seem to work
        )
    ]
end

function param_axes(sf::Base.Iterators.ProductIterator, axes = [])
    for it in sf.iterators
        param_axes(it, axes)
    end
    return axes
end
function param_axes(s::CedarSim.Sweep, axes = [])
    push!(axes, (s.selector, s.values))
    return axes
end
param_axes(sf::CedarSim.SweepFlattener, axes = []) = param_axes(sf.iterator, axes)
param_axes(x, axes) = throw(ArgumentError("Cannot build parameters for sweep of type $(typeof(x))"))

function params_sliders(subfig, sp)
    if sp.params !== nothing
        sg = SliderGrid(
            subfig,
            ((label = String(selector),
            range = 1:length(values),
            format = idx -> CedarWaves.display_value(values[idx]),
            startvalue = median(1:length(values)),
            ) for (selector, values) in param_axes(sp.params))...,
        )
        sliderobservables = [s.value for s in sg.sliders]
        idxs_selector = lift(sliderobservables...) do idxs...
            return idxs
        end
    else
        idxs_selector = convert(Observable, [1])
    end
end

"""
    explore(sp::SimParameterization)

`explore(sp)` with no solution passed in will default to `explore(sp, tran!(sp))`, see
the documentation for the `explore(sp, ::TransientSolutionType)` method for more details.
"""
explore(sp::SimParameterization) = explore(sp::SimParameterization, tran!(sp))

"""
    explore(sp::SimParameterization, ss::SensitivitySolutionType; with_transient = true)

Display a figure exploring the sensitivity results from a [`sensitivities!()`](@ref) call.
If `with_transient` is set to `true`, also displays the transient solution.
If solved across a parameter sweep, sliders allow exploration of the sensitivities across
different points along the sweep.
"""
function explore(sp::SimParameterization, ss::SensitivitySolutionType; with_transient::Bool=true)
    fig = Figure(; fontsize=18)

    n_params = length(get_param_names(ss))

    # Create slider for each parameterization in `sp`
    idxs_selector = params_sliders(fig[n_params+with_transient+1, 1], sp)

    xtickformat = CedarWaves.default_xtickformat()
    ytickformat = CedarWaves.default_ytickformat()

    if with_transient
        ax = Axis(fig[1, 1:2]; xlabel="Time (s)", ylabel="Amplitude (v)",
                  title=L"Transient Solution$$",
                  xtickformat, ytickformat,
                  )

        for measure_or_check in vcat(sp.saved_signals, sp.trchecks)
            trace = lift(idxs_selector) do idxs
                return apply(ss, measure_or_check, idxs)
            end
            label = lift(trace) do trace
                return get_label(trace, measure_or_check)
            end
            signalplot2!(ax, trace, label=label)
        end

        # Recipe limits have a bug: https://github.com/MakieOrg/Makie.jl/issues/3051
        tspan = first(ss.sols).prob.tspan
        xlims!(ax, tspan[1], tspan[2])
    end

    ax = nothing
    for (i, param) in enumerate(get_param_names(ss))

        # p_val => p_{val}
        latex_param = replace(string(param), r"_([a-zA-Z]*)" => s"_{\1}")

        ax = Axis(fig[i+with_transient, 1:2];
                    xlabel="Time (s)",
                    ylabel="Amplitude (v)",
                    title=L"$%$(latex_param)$ sensitivity $(\frac{∂}{∂%$(latex_param)})$",
                    xtickformat, ytickformat,
                    )
        for (i, measure_or_check) in enumerate(sp.saved_signals)
            trace = lift(idxs_selector) do idxs
                # We don't yet support checks on sensitivities
                return get_sensitivity(ss, measure_or_check, param, idxs)
            end
            label = lift(trace) do trace
                return get_label(trace, measure_or_check)
            end
            signalplot2!(ax, trace, label=label)
        end

        # Recipe limits have a bug: https://github.com/MakieOrg/Makie.jl/issues/3051
        tspan = first(ss.sols).prob.tspan
        xlims!(ax, tspan[1], tspan[2])
    end

    fig[n_params+with_transient+1, 2] = Legend(fig, ax, patchsize = (30, 30), tellheight = true)

    return fig
end

"""
    explore(sp::SimParameterization, ts::TransientSolutionType)

Display a figure exploring the sensitivity results from a [`tran!()`](@ref) call.
If solved across a parameter sweep, sliders allow exploration of the transients across
different points along the sweep.
"""
function explore(sp::SimParameterization, ts::Union{TransientSolutionType,SurrogateSolutionType})
    fig = Figure(; fontsize=18)
    xtickformat = CedarWaves.default_xtickformat()
    ytickformat = CedarWaves.default_ytickformat()

    ax = Axis(fig[1, 1:2]; xlabel="Time (s)", ylabel="Amplitude (v)",
                            xtickformat, ytickformat)

    # Create slider for each parameterization in `sp`
    idxs_selector = params_sliders(fig[2, 1], sp)

    for measure_or_check in vcat(sp.saved_signals, sp.trchecks)
        trace = lift(idxs_selector) do idxs
            return apply(ts, measure_or_check, idxs)
        end
        label = lift(trace) do trace
            return get_label(trace, measure_or_check)
        end
        signalplot2!(ax, trace, label=label)
    end

    fig[2, 2] = Legend(fig, ax, patchsize = (30, 30), tellheight = true)

    # Recipe limits have a bug: https://github.com/MakieOrg/Makie.jl/issues/3051
    tspan = first(ts.sols).prob.tspan
    xlims!(ax, tspan[1], tspan[2])
    return fig
end

"""
    explore(sp::SimParameterization, as::ACSolutionType)

Display a figure exploring the frequency response results from an [`ac!()`](@ref) call.
If solved across a parameter sweep, sliders allow exploration of the frequency response
across different points along the sweep.
"""
function explore(sp::SimParameterization, as::ACSolutionType)
    fig = Figure(; fontsize=18)
    xtickformat = CedarWaves.default_xtickformat(; sigdigits=4)
    ytickformat = CedarWaves.default_ytickformat(; sigdigits=4)
    ax = Axis(fig[1, 1:2];
        xlabel="Frequency (Hz)",
        ylabel="Magnitude",
        xscale = log10,
        yscale = log10,
        xtickformat,
        ytickformat,
    )

    # Create slider for each parameterization in `sp`
    idxs_selector = params_sliders(fig[2, 1], sp)
    ωs = as.ωs

    for measure_or_check in vcat(sp.saved_signals, sp.acchecks)
        trace = lift(idxs_selector) do idxs
            return apply(as, measure_or_check, idxs)
        end
        label = lift(trace) do trace
            return get_label(trace, measure_or_check)
        end
        signalplot2!(ax, trace, label=label)
    end

    fig[2, 2] = Legend(fig, ax, patchsize = (30, 30), tellheight = true)

    # Recipe limits have a bug: https://github.com/MakieOrg/Makie.jl/issues/3051
    xlims!(ax, ωs[1], ωs[end])
    return fig
end

"""
    explore(sp::SimParameterization, as::NoiseSolutionType)

Display a figure exploring the frequency response results from a [`noise!()`](@ref) call.
If solved across a parameter sweep, sliders allow exploration of the frequency response
across different points along the sweep.
"""
function explore(sp::SimParameterization, as::NoiseSolutionType)
    fig = Figure(; fontsize=18)
    xtickformat = CedarWaves.default_xtickformat(; sigdigits=4)
    ytickformat = CedarWaves.default_ytickformat(; sigdigits=4)
    ax = Axis(fig[1, 1:2];
        xlabel="Frequency (Hz)",
        ylabel="V/√Hz",
        xscale = log10,
        yscale = log10,
        xtickformat,
        ytickformat,
    )

    # Create slider for each parameterization in `sp`
    idxs_selector = params_sliders(fig[2, 1], sp)
    ωs = as.ωs

    for measure_or_check in vcat(sp.saved_signals, sp.noisechecks)
        trace = lift(idxs_selector) do idxs
            return apply(as, measure_or_check, idxs)
        end
        label = lift(trace) do trace
            return get_label(trace, measure_or_check)
        end
        signalplot2!(ax, trace, label=label)
    end

    fig[2, 2] = Legend(fig, ax, patchsize = (30, 30), tellheight = true)

    # Recipe limits have a bug: https://github.com/MakieOrg/Makie.jl/issues/3051
    xlims!(ax, ωs[1], ωs[end])
    return fig
end

"""
    plot_check(sp, cs)

Plot a single check along with all of the measures in a particular `sp`
"""
function plot_check(sp::SimParameterization, ts::TransientSolutionType, idxs, check)
    @assert length(ts) == 1

    sol = ts.sols::SciMLBase.AbstractODESolution
    fig = Figure(; fontsize=18)
    xtickformat = CedarWaves.default_xtickformat()
    ytickformat = CedarWaves.default_ytickformat()
    ax = Axis(fig[1, 1:2];
        xlabel="Time (s)",
        ylabel="Amplitude (v)",
        title=param_summary(sol),
        xtickformat, ytickformat,
    )

    for sig in sp.saved_signals
        trace = apply(ts, sig, idxs)
        signalplot2!(ax, trace; label=get_label(trace, sig))
    end

    trace = apply(ts, check, idxs)
    signalplot2!(ax, trace; label=get_label(trace, check))

    # Recipe limits have a bug: https://github.com/MakieOrg/Makie.jl/issues/3051
    xlims!(ax, sol.t[begin], sol.t[end])
    return fig
end

## Default show method to display a signal graphically if
#function Base.show(io::IO, m::MIME"juliavscode/html", s::AbstractSignal)
#    Base.show(io, m, signalplot2(s))
#end
