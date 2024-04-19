using CedarEDA
using CedarEDA.SIFactors: f, p, n, u, m, k, M, G

configure_logging!(log_file="inverter.log");

path = joinpath(@__DIR__, "inverter_cmg_cedar.cir")
sm = SimManager(path)

# ideally I'd like to sweep over more high-level parameters like
# - W/L ratio
# - area
# - N/P ratio
# the trouble is that NF is an integer parameter so it makes no sense to sweep small increments.
# this is more the reality of finfet design than a limitation of CedarEDA.
# but these are the things you actually care about rather than individual transistor sizes.
params = ProductSweep(
    nnf=1:1:5,
    pnf=1:1:5,
    # adding parameters makes initialisation worse
    #pl=21n.*(0.5:.5:2),
    #nl=21n.*(0.5:.5:2),
)

sp = SimParameterization(sm;
    params = params,
    abstol_dc = 100f,
)

set_saved_signals!(sp, [
    sp.probes.node_q,
]);

# our checks API is really bad
# - we can't express arbitrary measurements
# - we make hardcoded assumptions about complex signals (we take the magnitude)
# - our checks return strings that can't be further analysed or filtered into a sweep
#
# the flow I'd like to express here is to iteratively narrow down the valid parameter space
# 1. find dimensions where the inverter output is around vdd/2
# 2. find dimensions where the gain over a certain bandwith is over a minimum
# 3. find dimensions where the noise factor is below a certain threshold
set_checks!(sp,
dc=[sp.probes.node_q in CedarWaves.Interval(0.4, 0.6)],
ac=[ymax(sp.probes.node_q) in CedarWaves.Interval(1, 10)],
);

# the warnings here are confusing;
# which solver actually worked, and can I trust the results?
dcsol = dc!(sp)

dcresults = check(sp, dcsol)

# no dc explore
# figure = explore(sp, dcsol, dcsol.parameters.pl)

# Run the AC simulations with 40 points per decade from 10kHz to 1GHz
acsol = ac!(sp, acdec(40, 10k, 1G))

acresults = check(sp, acsol)

# the plot boundaries don't contain the entire sweep but only the midpoint
# this results in an empty plot most of the time
figure = explore(sp, acsol)

# Error: Exception while generating log record in module CedarEDA at /mnt/wsl/bizpep/home/pepijn/code/CedarEDA/src/SimManager/SimManager.jl:363
noisesol = noise!(sp, acdec(40, 10k, 1G))

# no noise check
# noiseresults = check(sp, noisesol)

figure = explore(sp, noisesol)
