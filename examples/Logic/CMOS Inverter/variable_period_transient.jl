using CedarEDA
using GF180MCUPDK

configure_logging!(log_file="variable_period.log")
# Load a SPICE netlist
sm = SimManager(joinpath(@__DIR__, "variable_period.spice"))

# Specify simulation parameters
sp = SimParameterization(sm;
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14,
    abstol_tran = 1e-4,
    maxiters = 5e9,
    tspan = (0.0, 5),
)

set_saved_signals!(sp, [
    sp.probes.node_vin,
    sp.probes.node_vout,
]);

# Run the transient analysis
ts = tran!(sp)

# Plot our variable-period signal
fig = explore(sp, ts)

# Export it to `.csv`
dir = "variable_period_csvs"
if !isdir(dir)
    mkdir(dir)
end
export_csvs(dir, sp)
