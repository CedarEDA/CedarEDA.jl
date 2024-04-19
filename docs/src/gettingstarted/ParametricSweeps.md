# Running Parametric Sweeps

```@setup parametric
using CedarEDA
using CairoMakie
CairoMakie.activate!()

# This gets the path to the `images` in this current directory.
include("../../docs_utils.jl")
```

Parametric sweeps allow us to explore the behavior of circuits as we change their parameters, and also define the basis upon which [Parameter Tuning with Optimization](@ref) is performed.
In this example, we will load the [Butterworth filter example circuit](@ref butterworth-example) and run a parametric sweep over its component values.
If you have not already, we recommend reviewing [Running Transient Analysis](@ref), as we will be building on top of the concepts covered within.

```@example parametric
using CedarEDA
using CedarEDA.SIFactors: f, p, n, u, m, k, M, G

# Load simple butterworth circuit
sm = SimManager("butterworth.spice")
```

After loading the spice code into the `SimManager` object, we can create our first parameterized sweep by creating a `SimParameterization` object and specifying the `params` keyword argument with a [`ProductSweep`](@ref).
Here we define ranges for the parameters using [Julia's step range syntax](https://docs.julialang.org/en/v1/base/math/#Base.StepRangeLen) which allows specifying `start:step:end` to easily create a list of numbers.
We also set tolerances for the solve, as well as the timespan over which this solve should occur.
```@example parametric
sp = SimParameterization(sm;
    # Sweep over these SPICE .parameters
    params = ProductSweep(
        l1 = 0.5n:0.25u:2.3u, # 10 values (step is 0.25u)
        c2 = 100p:100p:800p, # 8 values (step is 100p)
    ),
    abstol_dc = 10f,
    abstol_tran = 100u,
    reltol_tran = 1u,
    # 10 periods of the source sinusoid at 10MHz
    tspan = (0.0, 10/10M),
)
```

Once our [`SimParameterization`](@ref) object is created, we run a transient simulation which will run a sweep across the set of parameter values defined in the `sp` object:
```@example parametric
# Ensure that we plot `node_vout` by default
set_saved_signals!(sp, [
    sp.probes.node_vout,
]);

# Run the transient simulations
ts = tran!(sp)

# Explore our solution via Transient analysis
explore(sp, ts)
```

## Accessing sweep solution data

As mentioned in [Transient solution objects](@ref), [`SolutionSet`](@ref) objects are shaped the same as their originating parameterization.
In this example, we have two parameters combined in a [`ProductSweep`](@ref), resulting in a `8x10` matrix of simulations.
These simulations are directly accessable by index.
Here we demonstrate selecting two extremal simulations along the `l1` axis and plotting them on top of eachother using `inspect()`:

```@example parametric
inspect([
    ts.tran.node_vout[1, 4],
    ts.tran.node_vout[8, 4],
])
```

The parameter data for each simulation is also available through `ts.parameters`:
```@example parametric
ts.parameters.l1[1, 1]
```

```@example parametric
ts.parameters.c2[1, 1]
```

Parametric sweeps will be used extensively throughout the rest of this documentation.
See [Running DC Analysis](@ref) and [Parameter Tuning with Optimization](@ref) for more examples.

## Parameter sweep types

CedarEDA supports multiple types and combinations of parameter sweeps:

```@docs
ProductSweep
TandemSweep
SerialSweep
sweepvars
```

They can be nested and combined to create complex sweeps:

```@example parametric
sp = SimParameterization(sm;
    params = ProductSweep(
        r4 = range(0.1, 10.0; length=10),
        c2 = 0.2,
        TandemSweep(
            l1 = [0.1, 0.5, 1.0],
            w = 1:3,
        ),
    )
)
```
