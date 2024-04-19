using CedarEDA
using CedarEDA.SIFactors: f, p, n, u, m, k, M, G

sm = SimManager(joinpath(@__DIR__, "rc.spice"))

# Define our simulation parameters
R = 0.2
C = 0.5
params = ProductSweep(; r = [R], c = [C])
sp = SimParameterization(sm;
    # We're not really sweeping parameters here, just giving a default value.
    params,
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14, abstol_tran = 1e-6, reltol_tran = 1e-3,
    # Solve for this timescale
    tspan = (0.0, 10.0),
    preferred_solver = :Rodas5P,
)

# set_saved_signals!() will control which signals get plotted/exported to .csv
set_saved_signals!(sp, [
    sp.probes.node_vout,
    sp.probes.node_vin,
])

# Before we do anything else, inspect the transient and AC analyses for the circuit we just built.

# Plot the transient analysis
tran_sol = tran!(sp)
explore(sp, tran_sol)

# Plot the AC analysis as well
ac_sol = ac!(sp, acdec(40, 0.001, 100k))
explore(sp, ac_sol)

# Now that we know what the output looks like, we can try to optimize the circuit.
# First, we'll add some checks that we'd like to enforce for the transient response.
supply_levels = (0.0, 1.0)
# We set a risetime low percentage of 20%, and the high will be symmetric
# by default, so 80% of the supply levels.
risetime_low_pct = 0.2
risetime_measure = risetime(sp.probes.node_vout; supply_levels, risetime_low_pct)
set_checks!(sp, [
    # This risetime check plots the risetime, and alerts us if we stray outside of the given interval
    # In this case we are aiming for a rise time of between 0.9 and 1.1
    # which our default set of parameter will *not* achieve.
    risetime_measure in CedarWaves.Interval(0.09, 0.11),
]);

# This fails because the default parameters do not have a risetime between 0.9 and 1.1
check(sp)

# Inspect where this check failed in the transient analysis
explore(sp)

# We can see here that the risetime exceeds the upper bound we set (0.11)
rtime = risetime_measure(sp)

# Let's try to use parameter optimization to automatically tune resistance and
# capacitance to achieve a rise-time within our constraints.

# Define a loss function to optimize with respect to
function loss(sp)
    rtime = risetime_measure(sp)
    return (rtime.value - 0.1)^2 # trise target is 0.1s
end

# Optimize R and C with our loss function, to achieve the desired rise time
# of 0.1 seconds.
p0 = (r = R, c = C)
sp, sol_info = CedarEDA.optimize(loss, sp, p0;
    lb = (r = 0.1,  c = 0.00001),
    ub = (r = 1000.0, c = 1.0))

display(sp)
@show risetime_measure(sp)

# Now that we have tuned it we should see that check pass
check(sp)
explore(sp)

