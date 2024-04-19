using CedarEDA
using GF180MCUPDK


sm = SimManager(joinpath(@__DIR__, "amplifier.spice"))

# Define our simulation parameters
sp = SimParameterization(sm;
    # We're not really sweeping parameters here, just giving a default value.
    params = ProductSweep(; bias_current = [400e-6],),
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14, abstol_tran = 1e-6,
    # Solve for this timescale
    tspan = (0.0, 2e-5),
    # Rosenbrock23 is the best solver for this problem, save time by setting it as highest preference (optional)
    preferred_solver = :Rosenbrock23,
)

set_saved_signals!(sp, [
    sp.probes.node_vout,
    sp.probes.m2.var"I(di, si)",
])

# First, show the voltage of the `vout` net starting value
vout = tran!(sp).tran.node_vout[1]
vout_figure = inspect(vout, title="Starting Vout from netlist",
                            xlabel="Time (s)",
                            ylabel="Voltage (V)")
# Force plot in batch mode:
display(vout_figure)


# Solve the sensitivities, `ssols` has the same shape as our parameter sweep
# (in this case, only a single element), and each element of contains both
# the primal solution and the sensitivities with respect to each parameter,
# for each saved signal.
ssols = sensitivities!(sp)

# This displays the sensitivity of `node_vout` with respect to `bias_current` at the first parameterization point.
sens_vout_vs_ibias = ssols.sensitivities.node_vout.bias_current[1]
sens_vout_vs_ibias_fig = inspect(sens_vout_vs_ibias, title="Sensitivity of Vout to Ibias",
                                                     xlabel="Time (s)",
                                                     ylabel="δVout/δIbias (V/A)")
display(sens_vout_vs_ibias_fig) # force display in batch mode

# This displays the sensitivity of the current out of `m2` with respect to `bias_current` at the first parameterization point.
sens_m2cur_vs_ibias = ssols.sensitivities.m2.var"I(di, si)".bias_current[1]
sens_m2cur_vs_ibias_fig = inspect(sens_m2cur_vs_ibias, title="Sensitivity of M2 current to Ibias",
                                                           xlabel="Time (s)",
                                                           ylabel="δI(M2)/δIbias (A/A)")
display(sens_m2cur_vs_ibias_fig) # force display in batch mode


# We can check the derivative by running another simulation at a different (nearby) Ibias
# and checking that the derivative predicts the output accurately.
begin
    using WGLMakie
    ΔIbias = 10e-6
    perturbed_sp = SimParameterization(sm;
        # add a little shift in bias_current
        params = ProductSweep(; bias_current = [400e-6 + ΔIbias],),
        abstol_dc = 1e-14, abstol_tran = 1e-6,
        tspan = (0.0, 2e-5),
        preferred_solver = :Rosenbrock23,
    )
    set_saved_signals!(perturbed_sp, [
        sp.probes.node_vout,
    ])
    perturbed_sols = tran!(perturbed_sp)
    perturbed_signal = perturbed_sols.tran.node_vout[1]

    orig_sols = tran!(sp)
    orig_signal = orig_sols.tran.node_vout[1]
    orig_derivative = ssols.sensitivities.node_vout.bias_current[1]


    # Subtract the two signals, sampling the shifted signal at the timepoints
    # that `orig_signal` is defined on:
    predicted_signal = orig_signal + ΔIbias * sample(orig_derivative, xvals(orig_signal))

    # Display the error signal; note the relatively small error bounds
    error_signal = predicted_signal - sample(perturbed_signal, xvals(predicted_signal))

    fig = lines(xvals(orig_signal), yvals(orig_signal),
        label = "Original",
        axis = (
            title="Predicted output for Ibias=410uA vs Actual",
            xlabel = "Time (s)",
            ylabel = "Voltage (V)",
            xtickformat = CedarWaves.default_xtickformat(),
            ytickformat = CedarWaves.default_ytickformat(),
        )
    )
    lines!(xvals(predicted_signal), yvals(predicted_signal),
        label = "Predicted",
    )

    lines!(xvals(perturbed_signal), yvals(perturbed_signal),
        label = "Actual"
    )
    axislegend()
    display(fig)
end;
