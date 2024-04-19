# Working with Plots

CedarEDA provides a few convenience methods for working with plots (such as [`explore()`](@ref) and `inspect()`), however all plots are powered by the opensource [`Makie.jl` package](https://docs.makie.org/stable/) which provides high-quality graphics with a number of possible backends.
CedarEDA uses the [`WGLMakie` backend](https://docs.makie.org/stable/explanations/backends/wglmakie/) by default to provide interactive plots within your webbrowser, however other popular backends such as [`CairoMakie`](https://docs.makie.org/stable/explanations/backends/cairomakie/) can be used for static image output in many formats.

## Interacting with plots

Makie interactive plots can be interacted with in the following ways:

* Right-click drag to pan, `ctrl+click` to reset view

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/panning_clip.mp4" width="640" autoplay="" loop="true" muted="true" title="CedarEDA - Panning Plots"></video>
```

* Left-click drag to zoom, `ctrl+click` to reset view

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/zooming_clip.mp4" width="640" autoplay="" loop="true" muted="true" title="CedarEDA - Zooming Plots"></video>
```

* Left-click drag while holding `x` to zoom only along the X-axis

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/zooming_x_clip.mp4" width="640" autoplay="" loop="true" muted="true" title="CedarEDA - Zooming Plots Along X Axis"></video>
```

* Left-click drag while holding `y` to zoom only along the Y-axis

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/zooming_y_clip.mp4" width="640" autoplay="" loop="true" muted="true" title="CedarEDA - Zooming Plots Along Y Axis"></video>
```

* Left-click drag sliders to adjust values

```@raw html
<video src="https://help.juliahub.com/video/cedar-v0.4.5/sliding_clip.mp4" width="640" autoplay="" loop="true" muted="true" title="CedarEDA - Adjusting Sliders"></video>
```

!!! tip "Further Makie Documentation"
    For more details on the interactions available by default in interactive `Makie` plots, see [the `Axis` documentation upstream](https://docs.makie.org/stable/reference/blocks/axis/#axis_interaction).

## Saving figures to disk

When using the default `WGLMakie` backend, saving to `.png` is straightforward, simply use the `WGLMakie.save()` function:

```julia
fig = explore(sp)

using WGLMakie
save("output.png", fig)
```

To save into more exotic formats, you must use a different backend, such as `CairoMakie`:

```julia
using CairoMakie
CairoMakie.activate!()
save("output.svg", fig)
```

## CedarEDA convenience methods

CedarEDA provides the following convenience methods:

```@docs
explore

# Commenting this out until https://github.com/JuliaDocs/Documenter.jl/issues/2420 is solved
#CedarEDA.CedarWaves.inspect
```

