module TestMOI

using Test
import MathOptInterface as MOI
import cuPDLPx

function test_runtests()
    optimizer = cuPDLPx.Optimizer()
    MOI.set(optimizer, MOI.Silent(), true) # comment this to enable output
    model = MOI.Bridges.full_bridge_optimizer(
        MOI.Utilities.CachingOptimizer(
            MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
            optimizer,
        ),
        Float64,
    )
    config = MOI.Test.Config(
        rtol = 1e-1,
        atol = 1e-1,
        exclude = Any[
            MOI.ConstraintBasisStatus,
            MOI.VariableBasisStatus,
            MOI.ConstraintName,
            MOI.VariableName,
            MOI.ObjectiveBound,
            MOI.SolverVersion,
        ],
    )
    MOI.Test.runtests(
        model,
        config,
        # failed tests
        # some implementations not supported yet, such as reduced costs, TimeLimitSec, etc.
        exclude = [r"^test_infeasible_MAX_SENSE$",
                   r"^test_infeasible_MAX_SENSE_offset$",
                   r"^test_infeasible_MIN_SENSE$",
                   r"^test_infeasible_MIN_SENSE_offset$",
                   r"^test_infeasible_affine_MAX_SENSE$",
                   r"^test_infeasible_affine_MAX_SENSE_offset$",
                   r"^test_infeasible_affine_MIN_SENSE$",
                   r"^test_infeasible_affine_MIN_SENSE_offset$",
                   r"^test_linear_INFEASIBLE$",
                   r"^test_linear_INFEASIBLE_2$",
                   r"^test_linear_integration_delete_variables$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_EqualTo_lower$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_EqualTo_upper$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_GreaterThan$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_Interval_lower$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_Interval_upper$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_LessThan$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_VariableIndex_LessThan$",
                   r"^test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_VariableIndex_LessThan_max$",
                   r"^test_solve_VariableIndex_ConstraintDual_MAX_SENSE$",
                   r"^test_solve_VariableIndex_ConstraintDual_MIN_SENSE$",
                   r"^test_variable_solve_with_lowerbound$",
                   r"^test_variable_solve_with_upperbound$",
                  ],
        verbose = true,
    )
    return
end

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

end  # module

TestMOI.runtests()
