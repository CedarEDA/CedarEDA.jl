using CedarEDA

sm = SimManager(joinpath(@__DIR__, "rc.spice"))

# We're not really sweeping parameters here, just giving a default value.
R = 0.2
C = 0.5
sp = SimParameterization(sm;
    params = ProductSweep(; r = [R], c = [C]),
    # Solve to these tolerances for DC and Transient values
    abstol_dc = 1e-14, abstol_tran = 1e-6, reltol_tran = 1e-3,
    # Solve for this timescale
    tspan = (0.0, 10.0),
    preferred_solver = :Rodas5P,
)


set_saved_signals!(sp, [
    sp.probes.node_vout,
    sp.probes.node_vin,
])

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
# View the plot:
explore(sp)

# Solve for sensitivities and plot:
explore(sp, sensitivities!(sp))

# Show that the risetime exceeds the upper bound we set (0.11)
rtime = risetime_measure(sp)

####################
# Aim: automatically tune resistance and capacitance to achieve a rise-time of 0.1s
# This could easily be made more sophiticated, see the numerous examples below in this script.

function loss(sp)
    rtime = risetime_measure(sp)
    return (rtime.value - 0.1)^2 # trise target is 0.1s
end
loss(sp)

the_loss, pgrads = value_and_params_gradient(loss, sp)

######
# Let's compare the analytical end-to-end derivatives to the numerical ones
# (see README.md for derivation of the analytical derivatives)
# Calculated derivatives:
dldc_solved, dldr_solved = pgrads

# Analytic derivatives of the risetime from 20% to 80% with a loss funtion of `(trise-0.1)^2`
∂l∂c(R, C) = 2*R*( R*C*(log(0.8) - log(0.2)) - 0.1) * (log(0.8) - log(0.2))
∂l∂r(R, C) = 2*C*( R*C*(log(0.8) - log(0.2)) - 0.1) * (log(0.8) - log(0.2))
dldc_analytic = ∂l∂c(R, C)
dldr_analytic = ∂l∂r(R, C)

# The relative error between the two is 0.00404 (for both).
# This is because the circuit solver is using a reltol of 1e-3.
# If we use a reltol of 1e-6, the error is reduced to 9.4e-6:
dldc_relerr = (dldc_solved - dldc_analytic)/dldc_analytic
dldr_relerr = (dldr_solved - dldr_analytic)/dldr_analytic


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

#############################
# Some examples of alternative loss functions one might be interested in

# This is potentially more robust against initial conditions than just using
# risetime (which uses the first risetime)
function mean_risetime_loss(sp)
    measure = risetimes(sp.probes.node_vout; supply_levels, risetime_low_pct)
    rtimes = measure(sp)
    return (mean(rtimes).value - 0.1)^2
end

# Analytically, we expect this loss to be:
#    L(R,C)    = (R*C*log(1.0 / (1.0 - v_th)) - 0.1)^2
#
# with derivatives:
#   dL(R,C)/dC = 2*R*α*(R*C*α - 0.1)
#   dL(R,C)/dR = 2*C*α*(R*C*α - 0.1)
#
# where α = log(1.0 / (1.0 - v_th))
value_and_params_gradient(mean_risetime_loss, sp)

# We can use a sigmoid instead of just the squared loss, if we want to:
sigmoid(x) = x / (1 + abs(x)^2)
function strange_risetime_loss(sp)
    rtime = risetime_measure(sp)
    return sigmoid(10.0 * (rtime.value - 0.1))^2
end

# Analytically, we expect this loss to be:
#    L(R,C)    = sigmoid(10(R*C*α) - 0.1))^2
#
# with derivatives:
#   dL(R,C)/dC = 20*R*α*sigmoid(10(R*C*α - 0.1)) / (1 + abs(10*R*C*α - 1))^2
#   dL(R,C)/dR = 20*C*α*sigmoid(10(R*C*α - 0.1)) / (1 + abs(10*R*C*α - 1))^2
#
# where sigmoid(x) = x / (1 + abs(x)) and α = log(1.0 / (1.0 - v_th))
value_and_params_gradient(strange_risetime_loss, sp)

# We could combine multiple measures
function falltime_and_risetime_loss(sp)
    rmeasure = risetime(sp.probes.node_vout; supply_levels, risetime_low_pct)
    rtime =  rmeasure(sp)
    fmeasure = falltime(sp.probes.node_vout; supply_levels, risetime_low_pct)
    ftime =  fmeasure(sp)
    return (rtime.value + ftime.value - 0.2)^2
end
value_and_params_gradient(falltime_and_risetime_loss, sp)

# Or we could use delay instead
function delay_loss(sp)
    measure = delay(sp.probes.node_vin, sp.probes.node_vout)
    dtime = measure(sp)
    return (dtime.value - 0.05)^2
end
value_and_params_gradient(delay_loss, sp)


# or we could use the mean of all the delays
function mean_delay_loss(sp)
    measure = delays(sp.probes.node_vin, sp.probes.node_vout)
    dtime = mean(measure(sp))
    return (dtime.value - 0.05)^2
end
value_and_params_gradient(mean_delay_loss, sp)

p0 = (r = 0.2, c = 0.0001)
sp, sol_info = CedarEDA.optimize(mean_delay_loss, sp, p0;
    lb = (r = 0.1,  c = 0.00001),
    ub = (r = 1000.0, c = 1.0))

display(sp)
@show risetime_measure(sp)
