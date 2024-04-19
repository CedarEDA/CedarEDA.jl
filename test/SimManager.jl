using CedarEDA, Test

butterworth_dir = joinpath(@__DIR__, "..", "examples", "Filter", "Butterworth")
@testset "show() methods" begin
    sm = SimManager(joinpath(butterworth_dir, "butterworth.spice"))
    sm_out = repr(sm)
    @test contains(sm_out, "SimManager for 'butterworth.spice'")
    @test contains(sm_out, "- l1 (default: 1.2n)")

    sp = SimParameterization(sm;
        # Sweep over these SPICE .parameters
        params = ProductSweep(
            r4 = range(0.1, 10.0; length=10),
            c2 = 0.2,
            TandemSweep(
                l1 = range(0.1, 4.0; length=6),
                w = range(0.1, 0.5; length=6),
            ),
        ),
    )
    sp_out = repr(sp)
    @test contains(sp_out, "SimParameterization with parameterization:")
    @test contains(sp_out, "r4 (10 values: 100m .. 10)")
    @test contains(sp_out, "c2 = 0.2")
    @test contains(sp_out, "l1 (6 values: 100m .. 4)")
    @test contains(sp_out, "w  (6 values: 100m .. 0.5)")
end

@testset "solver choices" begin
    using SciMLBase: ODEProblem, DAEProblem
    using SciMLSensitivity: ODEForwardSensitivityProblem
    # Default solver ranking
    solvers = CedarEDA.solver_alternatives()
    @test nameof.(typeof.(solvers)) == [:IDA, :Rodas5P, :Rosenbrock23, :FBDF]
    # Preferred solver is put first
    solvers = CedarEDA.solver_alternatives(; preferred_solver = :Rosenbrock23)
    @test nameof.(typeof.(solvers)) == [:Rosenbrock23, :IDA, :Rodas5P, :FBDF]
    # Require an ODE solver
    solvers = CedarEDA.solver_alternatives(; problem_type = ODEProblem)
    @test nameof.(typeof.(solvers)) == [:Rodas5P, :Rosenbrock23, :FBDF]
    solvers = CedarEDA.solver_alternatives(; problem_type = ODEForwardSensitivityProblem)
    @test nameof.(typeof.(solvers)) == [:Rodas5P, :Rosenbrock23, :FBDF]
    # Require an ODE solver with preference
    solvers = CedarEDA.solver_alternatives(; preferred_solver = :Rosenbrock23, problem_type = ODEProblem)
    @test nameof.(typeof.(solvers)) == [:Rosenbrock23, :Rodas5P, :FBDF]
    solvers = CedarEDA.solver_alternatives(; preferred_solver = :Rosenbrock23, problem_type = ODEForwardSensitivityProblem)
    @test nameof.(typeof.(solvers)) == [:Rosenbrock23, :Rodas5P, :FBDF]
    # Require an DAE solver
    solvers = CedarEDA.solver_alternatives(; problem_type = DAEProblem)
    @test nameof.(typeof.(solvers)) == [:IDA]
    # Require an ODE solver with preference for a DAESolver: problem type wins
    solvers = CedarEDA.solver_alternatives(; preferred_solver = :IDA, problem_type = ODEProblem)
    @test nameof.(typeof.(solvers)) == [:Rodas5P, :Rosenbrock23, :FBDF]
    # Successful solver put first
    solvers = CedarEDA.solver_alternatives(; successful_solver = :Rosenbrock23)
    @test nameof.(typeof.(solvers)) == [:Rosenbrock23, :IDA, :Rodas5P, :FBDF]
    solvers = CedarEDA.solver_alternatives(; successful_solver = :Rosenbrock23, preferred_solver = :Rodas5P)
    @test nameof.(typeof.(solvers)) == [:Rosenbrock23, :Rodas5P, :IDA, :FBDF]
end

# Some bugs were identified in single-element sweeps, let's add some tests for them here.
@testset "Single-element sweeps" begin
    sm = SimManager(joinpath(butterworth_dir, "butterworth.spice"))
    sp = SimParameterization(sm;
        params = ProductSweep(r4 = range(0.1, 10.0; length=10)),
    )
    set_saved_signals!(sp, [sp.probes.node_vout])
    explore(sp)
end
