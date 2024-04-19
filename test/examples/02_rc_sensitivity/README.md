
## Example parameter sensitivity plots

As the script shows we can compute the sensitivity of the transient response to the parameters over time.
![](./images/Derivative_of_Circuit.png)

Further more, we can use that in an end-to-end process, computing the derivative of cost functions incorporating measures such as risetime..
This allowed automated tuning of the parameters.
![](./images/Derivative_end_to_end.png)


## Mathematical Derivation

The transient simulation after each rising pulse of 1 V is
$$
\begin{equation}
V(t) = 1-\exp\left(\frac{-t}{RC}\right)
\end{equation}
$$

To solve for risetime, we find the time at which $V(t)=.8$ and subtract from that when $V(t)=0.2$. First, we invert the voltage equation:
$$
\begin{equation}
V_{th}=1-\exp\left(\frac{-t}{RC}\right)
\end{equation}
$$

$$
\begin{equation}
1-V_{th}=\exp\left(\frac{-t}{RC}\right)
\end{equation}
$$

$$
\begin{equation}
\log(1-V)=\frac{-t}{RC}
\end{equation}
$$

$$
\begin{equation}
t=-R C\cdot\log(1-V)
\end{equation}
$$

Now we can use this inversion to find $V(t)=0.8$ and $V(t)=0.2$ and subtract, resulting in
$$
\begin{equation}
t_{rise} = V^{-1}(0.8)-V^{-1}(0.2)
\end{equation}
$$

$$
\begin{equation}
t_{rise} = \Big(-R C\cdot\log(1-0.8)\Big) - \Big(-R C\cdot\log(1-0.2)\Big)
\end{equation}
$$

$$
\begin{equation}
t_{rise} = -R C\cdot\log(0.2) + R C\cdot\log(0.8)
\end{equation}
$$

$$
\begin{equation}
t_{rise} = R C\cdot\log(0.8) - R C\cdot\log(0.2)
\end{equation}
$$

$$
\begin{equation}
t_{rise} = RC\left(\log(0.8) - \log(0.2)\right)
\end{equation}
$$

Now we can take derivatives with respect to our parameters, we can get
$$
\begin{equation}
\frac{\partial t_{rise}}{\partial R} = C\left(\log(0.8) - \log(0.2)\right)
\end{equation}
$$

and similarly,
$$
\begin{equation}
\frac{\partial t_{rise}}{\partial C} = R\left(\log(0.8) - \log(0.2)\right)
\end{equation}
$$

To optimize our circuit parameters for a risetime of 0.1, we define a loss function of
$$
\begin{equation}
Loss(R,C)=(t_{rise}-0.1)^2
\end{equation}
$$

which is the mean squared error.

We now can compute our sensitivities: $\frac{\partial Loss}{\partial R}$ and $\frac{\partial Loss}{\partial C}$

$$
\begin{equation}
\frac{\partial Loss}{\partial R}=\frac{\partial (t_{rise}-0.1)^2}{\partial R}
\end{equation}
$$

The chain rule is used for taking the derivative of a function composition
$$
\begin{equation}
\frac{\partial f(g(x))}{\partial x} = \frac{\partial g(x)}{\partial x}\cdot f\prime(g(x))
\end{equation}
$$
we have for $\frac{\partial Loss}{\partial R}$

$$
\begin{equation}
\frac{\partial (t_{rise}-0.1)^2}{\partial R} = 2(t_{rise}-0.1)\frac{\partial t_{rise}}{\partial R}
\end{equation}
$$
substituding in equation 10 for $t_{rise}$ gives
$$
\begin{equation}
\frac{\partial Loss}{\partial R}=2\Big( RC\big(\log(0.8) - \log(0.2)\big) - 0.1\Big) \frac{\partial t_{rise}}{{\partial R}}
\end{equation}
$$
and substituting in equation 11 for $\frac{\partial t_{rise}}{{\partial R}}$
$$
\begin{equation}
\frac{\partial Loss}{\partial R}=2\Big( R C\big(\log(0.8) - \log(0.2)\big) - 0.1\Big) \Big( C\big(\log(0.8) - \log(0.2)\big)\Big)
\end{equation}
$$


Cleaning this up gives

$$
\begin{equation}
\frac{\partial Loss}{\partial R} = 2C\Big( RC\big(\log(0.8) - \log(0.2)\big) - 0.1\Big) \Big( \log(0.8) - \log(0.2)\Big)
\end{equation}
$$


The derivative with respect to $C$ by symmetry is

$$
\begin{equation}
\frac{\partial Loss}{\partial C} = 2R\Big( RC\left(\log(0.8) - \log(0.2)\right) - 0.1\Big) \Big( \log(0.8) - \log(0.2)\Big)
\end{equation}
$$

As you can see, at optimaliatiy the derivative of the loss function (by definition) must be 0, which is achieved since

$$
\begin{equation}
RC\big(\log(0.8) - \log(0.2)\big) - 0.1 = 0
\end{equation}
$$

Solving for optimal RC:
$$
\begin{equation}
RC= \frac{0.1}{\log(0.8) - \log(0.2)}
\end{equation}
$$

Where target `trise=0.1` and `Vth1=0.2` and `Vth2=0.8`
$$
\begin{equation}
RC= \frac{t_{rise}}{\log(V_{DD}-V_{th2}) - \log(V_{DD}-V_{th1})}
\end{equation}
$$

We can check these derivatives with Cedar via `the_loss, pgrads = value_and_params_gradient(loss, sp)` which for our initial conditions of `R=0.2` and `C=0.5` returns `[0.021507321504013435, 0.0537683037591144]` for the gradient with respect to the parameters. This matches the analytic solution above which when translated into Julia it produces:
```julia
# Analytic end-to-end derivatives with respect to RC params
# Define equations:
∂l∂c(R, C) = 2*R*( R*C*(log(0.8) - log(0.2)) - 0.1) * (log(0.8) - log(0.2))
∂l∂r(R, C) = 2*C*( R*C*(log(0.8) - log(0.2)) - 0.1) * (log(0.8) - log(0.2))
# Calculate:
dldc_analytic = ∂l∂c(0.2, 0.5) # 0.021420707782116594
dldr_analytic = ∂l∂r(0.2, 0.5) # 0.053551769455291484
# If we compare the solved solution (using a reltol=1e-3) we have:
dldc_solved = 0.021507321504013435
dldr_solved = 0.0537683037591144
# Relative error:
dldc_relerr = (dldc_solved - dldc_analytic)/dldc_analytic # 0.004043457516803016
dldc_relerr = (dldr_solved - dldr_analytic)/dldr_analytic # 0.004043457499638599
```

The relative error between the solved and analytic solutions is about `0.004`.
This mismatch is due to the error tolerance of the simulator set to `reltol=0.001`.
If we use `reltol=1e-6` then the relative error will decrease to `9.4e-6`.
It is important to note that the simulator error control is for each timestep and
there is no guarantee that multiple timesteps will keep the error below the
tolerance.
Also the sensitivity of the measurement can cause the relative
error to go above `reltol`.

Through this simple example we have shown that CedarSim using Auto-Differentiation (AD) can automatically calculate the end-to-end derivaties through user-defined loss functions on arbitary circuits.  Having access to the end-to-end derivatives aids designer insights and enables faster and more robust optimization and machine learning.

