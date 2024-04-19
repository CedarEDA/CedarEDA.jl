# Running AC Analysis

Transient analysis solves for the evolution of a circuit's currents and voltages over time.
We will showcase here the steps to run a transient analysis, using the circuit from the [Butterworth filter example](@ref butterworth-example).
If you have not already, we recommend reviewing [Running Transient Analysis](@ref), and [Running Parametric Sweeps](@ref) as we will be building on top of the concepts covered within.

As a first step, we load the `SPICE` file and prepare a parameterization.
We will here sweep parameters setting the input voltage to this op-amp, looking to see the output voltage follow the input voltage, but saturating at some point based on the properties of the amplifier:

```@example ac_analysis
using CedarEDA
# Import some useful suffixes for SI units
using CedarEDA.SIFactors: p, n, u, m, k, M, G

sm = SimManager(joinpath(@__DIR__, "butterworth.spice"))
sp = SimParameterization(sm;
    # Sweep over these SPICE .parameters
    params = ProductSweep(
        l1 = 0.5n:0.25u:2.3u, # 10 values (step is 0.25u)
        c2 = 100p:50p:800p, # 15 values (step is 50p)
        l3 = 100n:50n:500n, # 9 values (step is 50n)
    ),
)
```

We will use [`explore()`](@ref) to visualize the frequency response, and so we will mark the signals we are interested in visualizing:

```@example ac_analysis
# Add signals to be automatically plotted
set_saved_signals!(sp, [
    sp.probes.node_vin,
    sp.probes.node_vout,
]);

# Run the AC simulations with 40 points per decade from 10kHz to 1GHz
ac_sol = ac!(sp, acdec(40, 10k, 1G))

explore(sp, ac_sol)
```

Because this is a third-order butterworth filter, we expect the filter to drop roughly three orders of magnitude for every decade of frequency increase.
Inspecting the figure above, we see this is indeed the case.

## AC solution objects

Just as with a transient analysis solution, an AC analysis solution contains within it the `parameters` and `op` properties, however here we will focus on the `ac` property:
```@repl ac_analysis
ac_sol.ac
```

When we index the `ac` property, pulling out a solution for a particular parameterization point, the return value is a complex-valued Signal, representing the frequency domain.
A common task is to visualize the magnitude or phase of the signal, which can be done via the `abs()` and `angle()` methods in Julia.
As showcased in [Working with Plots](@ref), the `inspect()` function can take in arrays of signals to plot.
Here, we demonstrate how to visualize the effect that varying the first parameter has on our output:

```@example ac_analysis
using CairoMakie # hide
CairoMakie.activate!() # hide

inspect([abs(sig) for sig in ac_sol.ac.node_vout[1, 1, :]])
```

!!! tip "Creating custom plots"
    While CedarEDA comes with many useful plotting utilities such as `inspect()` and [`explore()`](@ref), the full power of the Julia plotting ecosystem is available to you.
    Internally, CedarEDA makes use of [the `Makie` plotting library](https://docs.makie.org/stable/), with the `WGLMakie` backend for interactive plots.
