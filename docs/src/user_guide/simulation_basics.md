# Simulation Basics

CedarEDA makes use of a complex simulation engine written in the [Julia](https://julialang.org/) programming language, to compile high-performance simulation codes for circuit simulation and analysis.
CedarSim, the circuit simulation engine, is capable of parsing and compiling netlists defined in [SPICE](@ref SPICE-Syntax-Support) and [Spectre](@ref Spectre-Syntax-Support), as well as compiling device models defined in Verilog-A.
Internally, netlists and device models are compiled to an efficient internal representation that is then transformed into various forms to power the transient, AC, and sensitivity analyses the simulation engine supports.

## Compiled Simulation

CedarEDA's compiler produces efficient machine code for the particular circuit (and the particular parameterization of that circuit).
The same compiled code can be used with different parameter values which powers our ability to rapidly evaluate parameter sweeps.
This yields a very high-performance simulation loop, but constitues a trade-off for high compilation times.
As of the initial alpha release, compilation time is known to be prohibitive for circuits containing more than a few dozen transistors, see [our public issue tracker](https://github.com/CedarEDA/PublicIssues) for more known issues.
The Cedar team is prioritizing these known issues and will periodically release updates that should address all known shortcomings.

## Sensitivity Analysis

Our compiler pipeline is able to make use of [automatic differentiation](https://en.wikipedia.org/wiki/Automatic_differentiation) (AD) to power parameter optimization through [sensitivity analysis](https://en.wikipedia.org/wiki/Sensitivity_analysis).
This allows CedarEDA to determine which parameter values most effect output values of interest, including user-defined measures.
For a more fully-worked example of the power of sensitivity analysis, see [Parameter Tuning with Optimization](@ref).

Sensitivity Analysis is one of the most unique features of the CedarEDA suite, however it is also one of our most experimental.
Please report any issues encountered on [our public issue tracker](https://github.com/CedarEDA/PublicIssues).
