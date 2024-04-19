using CedarEDA
using GF180MCUPDK

configure_logging!(log_file="gf180_dff.log",)
# Load a SPICE netlist that has .parameters
sm = SimManager(joinpath(@__DIR__, "gf180_dff.spice"))

# Define our simulation parameters
sp = SimParameterization(sm;
    # Define a parameter sweep over the following parameters embedded within the SPICE netlist
    params = ProductSweep(;
        cload = logspace(100e-15, 80e-12, length=20),
        cglitch = logspace(10e-15, 1e-12, length=20),
    ),
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14,
    abstol_tran = 1e-4,

    # Solve for this timescale
    tspan = (0.0, 1.8e-6),
)


# Add measures to plot our relevant signals and parameters
set_saved_signals!(sp, [
    # These two Probe's are straightforward; just plot these signals.
    sp.probes.node_q,
    sp.probes.node_clkn,
]);

supply_levels = [0, 5]
set_checks!(sp, [
    # This risetime check plots the risetime, and alerts us if we stray outside of the given interval
    risetime(sp.probes.node_q; supply_levels, risetime_low_pct=0.2) in CedarWaves.Interval(0.0, 150e-9),

    # This delay checks the delay between `clkn` and `q`, alerting us if we stray over 100us.
    delay(sp.probes.node_clkn, sp.probes.node_q; supply_levels, dir1=falling, dir2=rising) in CedarWaves.Interval(0.0, 100e-9),
]);

# Explore our solutions
figure = explore(sp)

# Run our checks over all simulations, printing out a table summary
results = check(sp)

# Show that our DC solution maintains some useful properties
ds = dc!(sp)
@assert all(ds.op.node_d .≈ 0.0)
