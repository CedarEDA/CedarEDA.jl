using CedarEDA, Surrogatize, Flux

sm = SimManager(joinpath(@__DIR__, "test_surr.scs"))
surrsm = load_surrogate(joinpath(@__DIR__, "test.surr"), sm)

surrsp = SimParameterization(surrsm;
    params=ProductSweep(
        Iph = range(1.0, 2.0; length=2),
        not_Iph = [1.0]
    ),
    abstol_dc = 1e-12,
    abstol_tran = 1e-6,
    reltol_tran = 1e-4,
    tspan = (0.0, 1.5),
)
tran!(surrsp)
