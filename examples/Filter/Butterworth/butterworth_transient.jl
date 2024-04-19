# Press Shift-Enter to run each line of this file (interactively)
using CedarEDA

# Convenient multipliers for SI units for numbers (eg `2.4G`)
using CedarEDA.SIFactors: f, p, n, u, m, k, M, G

# Log output to a file
configure_logging!(log_file="butterworth_transient.log");

# Load a SPICE netlist that has defined:
# 1. A .param statement with the parameters to sweep
# 2. At least one transient source
# `@__DIR__` is the directory of this file
sm = SimManager(joinpath(@__DIR__, "butterworth.spice"))

# Using the `.param` names from the netlist, define
# which ones to sweep and their values.
# `ProductSweep` is a convienent way to sweep over all
# combination of values.
params = ProductSweep(
    l1 = 0.5n:0.25u:2.3u, # 10 values (step is 0.25u)
    c2 = 100p:50p:800p, # 15 values (step is 50p)
    l3 = 100n:50n:500n, # 9 values (step is 50n)
    freq = logspace(1M, 30M, length=10), # for SIN source
);

# Define our simulation parameters for transient analysis
sp = SimParameterization(sm;
    # Sweep over these SPICE .parameters
    params = params,
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 10f,
    abstol_tran = 100u,
    reltol_tran = 1u,
    tspan = (0.0, 10/10M), # 10 periods of the source at 10MHz
)

# Run the transient simulations over the parametric sweep
sol = tran!(sp)

# Add singals to be automatically plotted
set_saved_signals!(sp, [
    sp.probes.node_vout,
]);

# Add checks to be automatically run
set_checks!(sp,
    [
        # Check that the peak output voltage is between 0.5 and 1 V
        ymax(sp.probes.node_vout) in CedarWaves.Interval(0.5, 1),
    ]
)

# Interactively plot the saved signals and checks over the parametic sweep
fig = explore(sp, sol)
