using CedarEDA
using Test
using CedarWaves.SIFactors: f, p, n, u, m, k, M, G

reltol = 1e-6
abstol = 1e-12
vntol = 1e-6

tsm = @elapsed sm = SimManager(joinpath(@__DIR__, "resistor.sp"))
tsp = @elapsed sp = SimParameterization(sm;
    params = ProductSweep(; vdc = 1.0:1.0), # TODO: Remove once CedarSim.jl#763 lands
    # Solve to these tolerances for DC and Transient values
    abstol_dc = abstol, abstol_tran = abstol, reltol_tran = reltol,
    # Solve for this timescale
    tspan = (0, 1.0),
)
set_saved_signals!(sp, [
        sp.probes.node_in,
        sp.probes.node_out,
        sp.probes.v1.I,
    ]
)

dc1 = dc!(sp)

# TODO: These signals are empty, but we should have some means
#       of sampling them. Note that although this zero-state
#       system is constant, not all zero-state systems are.
tran1 = tran!(sp)
