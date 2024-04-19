import SciMLBase
import OptimizationOptimJL
using CedarEDA: SimParameterization, ProductSweep
using LineSearches: BackTracking
using Printf: @sprintf
using Optim: LBFGS

export optimize, OptimizationInfo

function SciMLBase.OptimizationProblem(
    sp::SimParameterization, loss::Function, p0
    ;lb = nothing, ub = nothing,
)   
    # Use the `p0` parameterization order as the canonical order
    v_p0 = convert(Vector{Float64}, collect(values(p0)))
    v_lb = Float64[getfield(lb, p) for p in keys(p0)]
    v_ub = Float64[getfield(ub, p) for p in keys(p0)]

    function with_params(sp, p′::Vector)
        sweep = ProductSweep(; (name => value for (name, value) in zip(keys(p0), p′))...)
        return SimParameterization(sp; params=sweep)
    end

    f(p, _) = begin
        any(p .<= 0.0) && return Inf # guard against physically unrealistic parameters
        sp′ = with_params(sp, p)
        return with_logger(NullLogger()) do
            loss(sp′)
        end
    end
    gradient!(J, p, _) = begin
        sp′ = with_params(sp, p)
        _, pgrads = value_and_params_gradient(loss, sp′)
        return J .= pgrads
    end
    of = SciMLBase.OptimizationFunction(f, SciMLBase.NoAD(); grad=gradient!)
    return SciMLBase.OptimizationProblem(of, v_p0, nothing; lb=v_lb, ub=v_ub)
end

"""
    OptimizationInfo

A struct to contain the results of a circuit optimization.
    
Contains two fields:
  - `history`: A vector of NamedTuples containing the parameters and loss seen at each iteration.
  - `sol`    : The OptimizationSolution object from Optimization.jl returned from Optimization.jl
"""
struct OptimizationInfo
    sol::SciMLBase.OptimizationSolution
    history::Vector
end


"""
    optimize(loss, sp, p0; lb, ub, optimizer=LBFG())

Optimize the circuit over the provided parameters for the given `loss`, and return an updated
SimParameterization with the optimal parameter values.

Information about the success/failure of optimization, convergence conditions, and loss per iteration
can be found in the returned OptimizationInfo object.

# Examples
```julia-repl
julia> p0 = (c_match = 1.5e-12, l_match = 150e-9); # initial guess
julia> lb = (c_match = 1.0e-12, l_match = 1e-9);   # lower-bound
julia> ub = (c_match = 1.0e-9, l_match = 1e-6);    # upper-bound
julia> sp, sol_info = CedarEDA.optimize(loss, sp; lb, ub);
julia> sol_info.retcode
```

# Arguments
  - `loss::Function`: The objective function for the optimization. The optimizer will attempt to
                      minimize the (scalar) output of this function.
  - `sp::SimParameterization`: The SimParameterization for the circuit to be optimized.
  - `p0::NamedTuple`: An initial guess for the optimal parameter values.
  - `lb::NamedTuple`: A lower-bound of the region to search for parameter values. Applies component-wise
                      to each parameter.
  - `ub::NamedTuple`: An upper-bound of the region to search for parameter values. Applies component-wise
                      to each parameter.
  - `optimizer`: The algorithm to use for optimization (e.g. BFGS, Gradient Descent, CG, etc.).
                 May be any Gradient-Free or Gradient-Required algorithm from [Optim.jl](https://julianlsolvers.github.io/Optim.jl/stable/).
"""
function optimize(loss::Function, sp::SimParameterization, p0::NamedTuple;
                  lb::NamedTuple = nothing, ub::NamedTuple = nothing,
                  optimizer=LBFGS(linesearch = BackTracking()),
                  timing=true)

    # Validate parameters
    for param in keys(lb)
        !in(param, keys(p0)) && throw(ArgumentError("`lb` included parameter $param but `p0` did not."))
    end
    for param in keys(ub)
        !in(param, keys(p0)) && throw(ArgumentError("`ub` included parameter $param but `p0` did not."))
    end
    for param in keys(p0)
        !in(param, keys(lb)) && throw(ArgumentError("`p0` included parameter $param but `lb` did not."))
        !in(param, keys(ub)) && throw(ArgumentError("`p0` included parameter $param but `ub` did not."))
    end
    any(values(lb) .<= 0.0) && throw(ArgumentError("`lb` values must be strictly positive"))

    sp′ = SimParameterization(sp; params=ProductSweep(; p0...))
    opt = SciMLBase.OptimizationProblem(sp′, loss, p0; lb, ub)
    
    history = @NamedTuple{loss::Float64, p::typeof(p0)}[]
    function callback(state, loss)
        p_nt = (; zip(keys(p0), state.u)...)
        push!(history, (; loss, p=p_nt))
        if timing
            @info "Iteration $(@sprintf("%3d", length(history))): cost=$loss"
        end

        halt = false
        return halt
    end
    sol = solve(opt, optimizer; callback)

    # Copy solution to a result SimParameterization
    sweep = ProductSweep(; (name => value for (name, value) in zip(keys(p0), sol.u))...)
    sp′ = SimParameterization(sp; params=sweep)

    return sp′, OptimizationInfo(sol, history)
end
