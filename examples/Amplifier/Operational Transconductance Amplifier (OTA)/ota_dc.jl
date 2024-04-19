using CedarEDA

configure_logging!(log_file = joinpath(@__DIR__, "fac14_ota_m1_t_dc.log"))
sm = SimManager(joinpath(@__DIR__, "ota.spice"))

dcsp = SimParameterization(sm;
    params = ProductSweep(;
        pv1 = 0:0.05:1.3,
    ),
    abstol_dc = 1e-10,
    preferred_solver = :Rodas5P,
)

set_saved_signals!(dcsp, [
    dcsp.probes.node_ninp,
    dcsp.probes.node_nout,
])

set_checks!(dcsp;
    dc=[
        # Rough sanity checks:
        # Check output signal swings from 0 to 5 (within 10% VDD)
        ymax(dcsp.probes.node_nout) in CedarWaves.Interval(2.5, 4.0),
        ymax(dcsp.probes.node_nout) in CedarWaves.Interval(0, 1.8),
    ],
)

dc1 = dc!(dcsp)

dcsig = PWL(dc1.parameters.pv1, dc1.op.node_nout)
inspect(dcsig, xlabel="V1 (V)", ylabel="Vout (V)", title="DC Sweep Transfer Curve")
