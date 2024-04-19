using CedarEDA
using Optim: LBFGS, BackTracking, BFGS
# Handy multipliers for SI units
using CedarWaves.SIFactors: f, p, n, u, m, k, M, G

# Load a SPICE netlist that has .parameters
sm = SimManager(joinpath(@__DIR__, "impedance_matcher.spice"))

# Define our simulation parameters
sp = SimParameterization(sm;
    # Sweep over these SPICE .parameters
    params = ProductSweep(;
        l_match = range(1.0n, 200n; length=20),
        c_match = range(0.1p, 20p; length=20),
    ),
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14,
    abstol_tran = 1e-4,
    tspan = (0.0, 4e-8),
    preferred_solver = :FBDF,
)

# A probe ensures this signal is plotted, saved out to `.csv`, etc...
set_saved_signals!(sp, [
    sp.probes.node_vsrc,
    sp.probes.node_vin,
    sp.probes.node_vout,
]);

# Explore our solution
fig = explore(sp)

####################

# We'll attempt to optimize the l_match and c_match to maximize the energy of the
# output signal. This should be the value at which the source impedance is matched
# to the characteristic 50 Ω impedance of the transmission line/load.
function loss(sp)
    t = range(2e-8, 10e-8, length=1000)
    measure = sample_at(sp.probes.node_vout, t)
    vout =  measure(sp)
    return -sum(abs2, vout) # Minimize negative energy to maximize energy
end


# First we'll take a quick look at our sensitivities around
# the impedance-matched solution.
sp = SimParameterization(sm;
    # Sweep over these SPICE .parameters
    params = ProductSweep(; c_match = 12.73p, l_match = 159.2n),
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14,
    abstol_tran = 1e-4,
    reltol_tran = 1e-4,
    tspan = (0.0, 40e-9),
    preferred_solver = :FBDF,
)

set_saved_signals!(sp, [
    sp.probes.node_vsrc,
    sp.probes.node_vin,
    sp.probes.node_vout,
]);

fig = explore(sp, sensitivities!(sp))

# Then, we'll attempt to converge to the same from a random
# guess using an optimizer
sp = SimParameterization(sm;
    # Sweep over these SPICE .parameters
    params = ProductSweep(; c_match = 1.5p, l_match = 400n),
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14,
    abstol_tran = 1e-4,
    reltol_tran = 1e-4,
    tspan = (0.0, 100e-9),
    preferred_solver = :FBDF,
)

set_saved_signals!(sp, [
    sp.probes.node_vout,
]);


loss(sp)
the_loss, pgrads = value_and_params_gradient(loss, sp)

# Do our optimization and verify that the result matches the theoretical
# optimum of (12.73 pF, 159.2 nH)
p0 = (c_match = 1.5p, l_match = 400n) # initial guess

sp, sol_info = CedarEDA.optimize(loss, sp, p0;
    lb = (c_match = 1p, l_match = 1n),
    ub = (c_match = 1n, l_match = 1u),
    optimizer=LBFGS(linesearch = BackTracking()));

# observed: (159.199 nH, 12.7413 pF) (L-BFGS)
isapprox(sol_info.history[end].p.c_match, 12.73p; rtol=0.01)
isapprox(sol_info.history[end].p.l_match, 159.2n ; rtol=0.01)

# Try again with another optimization algorithm (BFGS) and
# check that once again we converged to the optimal value.
sp, sol_info = CedarEDA.optimize(loss, sp, p0;
    lb = (c_match = 1p, l_match = 1n),
    ub = (c_match = 1n,  l_match = 1u),
    optimizer=BFGS(linesearch = BackTracking()));

# observed: (159.185 nH, 12.7408 pF) (BFGS)
isapprox(sol_info.history[end].p.c_match, 12.73p; rtol=0.01)
isapprox(sol_info.history[end].p.l_match, 159.2n ; rtol=0.01)
