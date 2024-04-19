# Press Shift-Enter to run each line of this file (interactively)
using CedarEDA

# Convenient multipliers for SI units for numbers (eg `2.4G`)
using CedarEDA.SIFactors: f, p, n, u, m, k, M, G

# Log output to a file
configure_logging!(log_file="butterworth.log");

# Load a SPICE netlist that has defined:
# 1. A .param statement with the parameters to sweep
# 2. A source with an `AC` stimulus
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
)

# Define our simulation parameters for AC analysis
sp = SimParameterization(sm;
    # Sweep over the parameters defined above
    params = params,
    # Solver tolerance for the smallest value of interest:
    abstol_dc = 10f,
)

# Add signals to be automatically plotted
set_saved_signals!(sp, [
    sp.probes.node_vout,
]);

# Run the AC simulations with 40 points per decade from 10kHz to 1GHz
sol = ac!(sp, acdec(40, 10k, 1G))

# Interactively plot the saved signals over the parametic sweep
figure = explore(sp, sol)
