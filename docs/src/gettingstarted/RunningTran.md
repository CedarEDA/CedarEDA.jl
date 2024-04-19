# Running Transient Analysis

Transient analysis solves for the evolution of a circuit's currents and voltages over time.
We will showcase here the steps to run a transient analysis, using the circuit from the [Butterworth filter example](@ref butterworth-example).

## Parsing and compiling the SPICE netlist

```@setup transient_analysis
using CedarEDA
using CairoMakie
CairoMakie.activate!()

include("../../docs_utils.jl")
```

To parse your SPICE file, pass a file path to the [`SimManager`](@ref) method.
The resultant object represents the parsed and analyzed circuit, and will be used to further create parameterizations and simulations of that circuit.
Here we are loading in the [`butterworth.spice`](@ref butterworth.spice) file

```@example transient_analysis
using CedarEDA
sm = SimManager("butterworth.spice")
```

CedarEDA features a fully-compiled simulator and will generate specialized machine code to most efficiently simulate this particular circuit, as well as the particular parameterization of this circuit.
For this first example, we will create a default parameterization of the circuit via the [`SimParameterization`](@ref) method.
We will tell this particular parameterization to solve over a specific timespan, from 0 to 100 seconds:

```@example transient_analysis
# Import some useful suffixes for SI units
using CedarEDA.SIFactors: f, u

sp = SimParameterization(sm; tspan=(0, 1u))
```

The `SimParameterization` object contains within it information about the circuit's signal probe points (`sp.probes`) which directly correspond to the SPICE file's device and net hierarchy.
```@repl transient_analysis
sp.probes
```

## Running transient simulations

Using this information, we are free to run a transient analysis and visualize the results.
The [`explore`](@ref) method provides a convenient way to visualize analysis results, and if passed a `SimParameterization` object in isolation, will automatically perform transient analysis.
`explore()` will plot any signals specified as a "saved signal", via the `set_saved_signals!()` method, which takes in probe points from `sp.probes`:
```@example transient_analysis

# Ensure that `vout` is plotted in `explore()`
set_saved_signals!(sp, [
    sp.probes.node_vout,
])
explore(sp)
```


Transient analysis is explicitly requested through [`tran!()`](@ref), which returns a [`SolutionSet`](@ref) object containing the transient signals and convenient syntax for obtaining the signals of interest:

```@example transient_analysis
tran_sol = tran!(sp)
```

## Transient solution objects

[`SolutionSet`](@ref) objects are shaped the same as their originating [`SimParameterization`](@ref) objects, yielding a natural method of accessing analysis results across parameter sweeps.
For an example of using results from a parameter sweep, see [Running Parametric Sweeps](@ref), but for now we know there is only a single simulation within this transient solution and so will index it by `[1]` to pull out the first element.

Transient solution objects contain within themselves three properties: `op`, `parameters` and `tran`.
The `op` property is discussed in greater detail in the section on [Running DC Analysis](@ref), and the `parameters` property is discussed in [Running Parametric Sweeps](@ref), and so we will concern ourselves only with the `tran` property here:

```@repl transient_analysis
tran_sol.tran
```

!!! tip "Signals in `SolutionSet`s"
    The `tran` property contains within it all signals within the circuit.
    Critically, one is able to obtain signals that were not listed in [`set_saved_signals!()`](@ref), all signals are always available from a solution object, but some may not be saved to `.csv` when exporting via [`export_csvs()`](@ref) or plotted via [`explore()`](@ref).

Signals obtained from [`SolutionSet`](@ref) objects are [`CedarWaves`](https://help.juliahub.com/cedarwaves/stable/) signal objects, and can be plotted via the `inspect()` function.
For more information about `CedarWaves`, view the [latest available documentation](https://help.juliahub.com/cedarwaves/stable/).
Here, we merely show the ease of extracting signals and plotting them, displaying `node_vin` against `node_vout` and demonstrating that the filter has indeed decreased the gain.
Remember that since our transient analysis contains only a single parameterization point (the default parameterization) we must index our solution signals by `[1]`.

```@example transient_analysis
# This will plot both signals within a single figure.
inspect([tran_sol.tran.node_vin[1], tran_sol.tran.node_vout[1]])
```

For more on interacting with plots see [Working with Plots](@ref).

## Exporting transient results

To export to `.csv`, one may use the [`export_csv()`](@ref) and [`export_csvs()`](@ref) functions.
This is typically used to dump either a specific signal to a single `.csv` file, or a whole set of simulations to a directory:

```@example transient_analysis
# Exporting a single signal as a `.csv`
export_csv("node_vout.csv", tran_sol.tran.node_vout[1])

# Exporting all saved signals, across all parameterization points
export_csvs("outputs", sp)
```
