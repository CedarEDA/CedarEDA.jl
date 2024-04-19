# Running DC Analysis

DC analysis solves for the initial conditions of a circuit's currents and voltages.
We will showcase here the steps to run a DC analysis, using the circuit from the [Op-Amp Example](@ref op-amp-example).
If you have not already, we recommend reviewing [Running Transient Analysis](@ref), and [Running Parametric Sweeps](@ref) as we will be building on top of the concepts covered within.

As a first step, we load the `SPICE` file and prepare a parameterization.
We will here sweep parameters setting the input voltage to this op-amp, looking to see the output voltage follow the input voltage, but saturating at some point based on the properties of the amplifier:

```@example dc_analysis
using CedarEDA

sm = SimManager(joinpath(@__DIR__, "ota.spice"))
# Sweep `pv1`, and solve the DC operating point to a tight tolerance
dc_sp = SimParameterization(sm;
    params = ProductSweep(;pv1 = 0:0.05:1),
)
dc_sol = dc!(dc_sp)
```

## DC Solution Objects

Just as with a transient analysis solution, a DC analysis solution contains within it a few properties:
```@repl dc_analysis
dc_sol.parameters
```
```@repl dc_analysis
dc_sol.op
```

Unlike the [`tran` property within a transient solution](@ref Transient-solution-objects), the values extracted from the `op` property are not signals but rather scalar floating point values, one for each point in the parameter sweep:
```@repl dc_analysis
dc_sol.op.node_nout[1:3]
```

This, combined with the scalars yielded by the `parameters` property makes it easy to visualize operating point sweep curves.
Here we make use of our `inspect()` function as before.
For more information on plotting in CedarEDA, see [Working with Plots](@ref).
```@example dc_analysis
using WGLMakie
using CairoMakie # hide
CairoMakie.activate!() # hide

inspect(
    # Create a signal containing operating point against parameter value
    Signal(dc_sol.parameters.pv1, dc_sol.op.node_nout),
    # Override the label names
    xlabel="V1 (V)",
    ylabel="Vout (V)",
    title="DC Sweep Transfer Curve",
)
```
!!! tip "Creating custom plots"
    While CedarEDA comes with many useful plotting utilities such as `inspect()` and [`explore()`](@ref), the full power of the Julia plotting ecosystem is available to you.
    Internally, CedarEDA makes use of [the `Makie` plotting library](https://docs.makie.org/stable/), with the `WGLMakie` backend for interactive plots.
