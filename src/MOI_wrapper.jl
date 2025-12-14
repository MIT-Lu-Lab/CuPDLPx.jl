import MathOptInterface as MOI

# Inspired from `Clp.jl/src/MOI_wrapper/MOI_wrapper.jl`
MOI.Utilities.@product_of_sets(
    _LPProductOfSets,
    MOI.EqualTo{T},
    MOI.GreaterThan{T},
    MOI.LessThan{T},
    MOI.Interval{T},
)

const OptimizerCache = MOI.Utilities.GenericModel{
    Cdouble,
    MOI.Utilities.ObjectiveContainer{Cdouble},
    MOI.Utilities.VariablesContainer{Cdouble},
    MOI.Utilities.MatrixOfConstraints{
        Cdouble,
        MOI.Utilities.MutableSparseMatrixCSC{
            Cdouble,
            Cint,
            MOI.Utilities.ZeroBasedIndexing,
        },
        MOI.Utilities.Hyperrectangle{Cdouble},
        _LPProductOfSets{Cdouble},
    },
}

Base.show(io::IO, ::Type{OptimizerCache}) = print(io, "cuPDLPx.OptimizerCache")

const BOUND_SETS = Union{
    MOI.GreaterThan{Float64},
    MOI.LessThan{Float64},
    MOI.EqualTo{Float64},
    MOI.Interval{Float64},
}

"""
    Optimizer()

Create a new cuPDLP optimizer.
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    result::Union{Nothing,LibcuPDLPx.cupdlpx_result_t}
    max_sense::Bool

    function Optimizer()
        return new(
            nothing,
            false,
        )
    end
end

function MOI.default_cache(::Optimizer, ::Type)
    return OptimizerCache()
end

# ====================
#   empty functions
# ====================

function MOI.is_empty(optimizer::Optimizer)
    return isnothing(optimizer.result)
end

function MOI.empty!(optimizer::Optimizer)
    optimizer.result = nothing
    return
end

MOI.get(::Optimizer, ::MOI.SolverName) = "cuPDLPx"

# MOI.RawOptimizerAttribute

function MOI.supports(::Optimizer, param::MOI.RawOptimizerAttribute)
    error("TODO")
    return hasfield(PdhgParameters, Symbol(param.name))
end

function MOI.set(optimizer::Optimizer, param::MOI.RawOptimizerAttribute, value)
    error("TODO")
    if !MOI.supports(optimizer, param)
        throw(MOI.UnsupportedAttribute(param))
    end
    setfield!(optimizer.parameters, Symbol(param.name), value)
    return
end

function MOI.get(optimizer::Optimizer, param::MOI.RawOptimizerAttribute)
    error("TODO")
    if !MOI.supports(optimizer, param)
        throw(MOI.UnsupportedAttribute(param))
    end
    return getfield(optimizer.parameters, Symbol(param.name))
end

# MOI.Silent

MOI.supports(::Optimizer, ::MOI.Silent) = true

function MOI.set(optimizer::Optimizer, ::MOI.Silent, value::Bool)
    error("TODO")
    optimizer.silent = value
    return
end

MOI.get(optimizer::Optimizer, ::MOI.Silent) = optimizer.silent

# ========================================
#   Supported constraints and objectives
# ========================================

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{<:BOUND_SETS},
)
    return true
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.ScalarAffineFunction{Float64}},
    ::Type{<:BOUND_SETS},
)
    return true
end


MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOI.supports(
    ::Optimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}},
)
    return true
end

# ===============================
#   Optimize and post-optimize
# ===============================

function _flip_sense(optimizer::Optimizer, obj)
    return optimizer.max_sense ? -obj : obj
end

function sparse_matrix(A::MOI.Utilities.MutableSparseMatrixCSC{Cdouble,Cint,MOI.Utilities.ZeroBasedIndexing})
    A_csc = LibcuPDLPx.MatrixCSC(
        length(A.rowval),
        pointer(A.colptr),
        pointer(A.rowval),
        pointer(A.nzval)
    )

    # 1. Allocate zeroed struct on Julia side
    A_desc_ref = Ref{LibcuPDLPx.matrix_desc_t}()
    A_desc_ref[] = LibcuPDLPx.matrix_desc_t(ntuple(_ -> UInt8(0), 56)) # Clear memory
    A_desc_ptr = Base.unsafe_convert(Ptr{LibcuPDLPx.matrix_desc_t}, A_desc_ref)

    # 2. Set Scalar Fields
    A_desc_ptr.m = Cint(A.m)
    A_desc_ptr.n = Cint(A.n)
    A_desc_ptr.fmt = LibcuPDLPx.matrix_csc
    A_desc_ptr.zero_tolerance = 0.0

    # 3. Set The Union Data
    A_desc_ptr.data.csc = A_csc

    return A_desc_ptr
end

function MOI.optimize!(dest::Optimizer, src::OptimizerCache)
    MOI.empty!(dest)
    dest.max_sense = MOI.get(src, MOI.ObjectiveSense()) == MOI.MAX_SENSE
    obj = MOI.get(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    c = zeros(Cdouble, src.constraints.coefficients.n)
    for term in obj.terms
        c[term.variable.value] += _flip_sense(dest, term.coefficient)
    end
    obj_const = [_flip_sense(dest, MOI.constant(obj))]
    prob = LibcuPDLPx.create_lp_problem(
        pointer(c),
        sparse_matrix(src.constraints.coefficients),
        pointer(src.constraints.constants.lower),
        pointer(src.constraints.constants.upper),
        pointer(src.variables.lower),
        pointer(src.variables.upper),
        pointer(obj_const)
    )
    @assert prob != C_NULL

    params_ref = Ref{Lib.pdhg_parameters_t}()
    Lib.set_default_parameters(Base.unsafe_convert(Ptr{Lib.pdhg_parameters_t}, params_ref))
    params_ptr = Base.unsafe_convert(Ptr{Lib.pdhg_parameters_t}, params_ref)

    result_ptr = Lib.solve_lp_problem(prob, params_ptr)
    @assert result_ptr != C_NULL
    dest.result = unsafe_load(result_ptr)
    return MOI.Utilities.identity_index_map(src), false
end

function MOI.optimize!(dest::Optimizer, src::MOI.ModelLike)
    cache = OptimizerCache()
    index_map = MOI.copy_to(cache, src)
    MOI.optimize!(dest, cache)
    return index_map, false
end

function MOI.get(optimizer::Optimizer, ::MOI.SolveTimeSec)
    return optimizer.result.cumulative_time_sec
end

function MOI.get(optimizer::Optimizer, ::MOI.RawStatusString)
    if isnothing(optimizer.result)
        return "Optimize not called"
    else
        error("TODO")
    end
end

const _TERMINATION_STATUS_MAP = Dict(
    LibcuPDLPx.TERMINATION_REASON_UNSPECIFIED => MOI.OPTIMIZE_NOT_CALLED,
    LibcuPDLPx.TERMINATION_REASON_OPTIMAL => MOI.OPTIMAL,
    LibcuPDLPx.TERMINATION_REASON_PRIMAL_INFEASIBLE => MOI.INFEASIBLE,
    LibcuPDLPx.TERMINATION_REASON_DUAL_INFEASIBLE => MOI.DUAL_INFEASIBLE,
    LibcuPDLPx.TERMINATION_REASON_TIME_LIMIT => MOI.TIME_LIMIT,
    LibcuPDLPx.TERMINATION_REASON_ITERATION_LIMIT => MOI.ITERATION_LIMIT,
    LibcuPDLPx.TERMINATION_REASON_FEAS_POLISH_SUCCESS => MOI.OTHER_ERROR, # TODO
)

# Implements getter for result value and statuses
function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return isnothing(optimizer.result) ? MOI.OPTIMIZE_NOT_CALLED :
           _TERMINATION_STATUS_MAP[optimizer.result.termination_reason]
end

function MOI.get(optimizer::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(optimizer, attr)
    return _flip_sense(optimizer, optimizer.result.iteration_stats[end].convergence_information[].primal_objective)
end

function MOI.get(optimizer::Optimizer, attr::MOI.DualObjectiveValue)
    MOI.check_result_index_bounds(optimizer, attr)
    return _flip_sense(optimizer, optimizer.result.iteration_stats[end].convergence_information[].dual_objective)
end

const _PRIMAL_STATUS_MAP = Dict(
    LibcuPDLPx.TERMINATION_REASON_UNSPECIFIED => MOI.NO_SOLUTION,
    LibcuPDLPx.TERMINATION_REASON_OPTIMAL => MOI.FEASIBLE_POINT,
    LibcuPDLPx.TERMINATION_REASON_PRIMAL_INFEASIBLE => MOI.NO_SOLUTION,
    LibcuPDLPx.TERMINATION_REASON_DUAL_INFEASIBLE => MOI.INFEASIBILITY_CERTIFICATE,
    LibcuPDLPx.TERMINATION_REASON_TIME_LIMIT => MOI.UNKNOWN_RESULT_STATUS,
    LibcuPDLPx.TERMINATION_REASON_ITERATION_LIMIT => MOI.UNKNOWN_RESULT_STATUS,
    LibcuPDLPx.TERMINATION_REASON_FEAS_POLISH_SUCCESS => MOI.UNKNOWN_RESULT_STATUS,
)

function MOI.get(optimizer::Optimizer, attr::MOI.PrimalStatus)
    if attr.result_index > MOI.get(optimizer, MOI.ResultCount())
        return MOI.NO_SOLUTION
    end
    return _PRIMAL_STATUS_MAP[optimizer.result.termination_reason]
end

function MOI.get(
    optimizer::Optimizer,
    attr::MOI.VariablePrimal,
    vi::MOI.VariableIndex,
)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.result.primal_solution[vi.value]
end

const _DUAL_STATUS_MAP = Dict(
    LibcuPDLPx.TERMINATION_REASON_UNSPECIFIED => MOI.NO_SOLUTION,
    LibcuPDLPx.TERMINATION_REASON_OPTIMAL => MOI.FEASIBLE_POINT,
    LibcuPDLPx.TERMINATION_REASON_PRIMAL_INFEASIBLE => MOI.INFEASIBILITY_CERTIFICATE,
    LibcuPDLPx.TERMINATION_REASON_DUAL_INFEASIBLE => MOI.NO_SOLUTION,
    LibcuPDLPx.TERMINATION_REASON_TIME_LIMIT => MOI.UNKNOWN_RESULT_STATUS,
    LibcuPDLPx.TERMINATION_REASON_ITERATION_LIMIT => MOI.UNKNOWN_RESULT_STATUS,
    LibcuPDLPx.TERMINATION_REASON_FEAS_POLISH_SUCCESS => MOI.UNKNOWN_RESULT_STATUS,
)

function MOI.get(optimizer::Optimizer, attr::MOI.DualStatus)
    if attr.result_index > MOI.get(optimizer, MOI.ResultCount())
        return MOI.NO_SOLUTION
    end
    return _DUAL_STATUS_MAP[optimizer.result.termination_reason]
end

function MOI.get(
    optimizer::Optimizer,
    attr::MOI.ConstraintDual,
    ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.EqualTo{Float64}},
)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.result.dual_solution[ci.value]
end

function MOI.get(
    optimizer::Optimizer,
    attr::MOI.ConstraintDual,
    ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.GreaterThan{Float64}},
)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.result.dual_solution[optimizer.num_equalities + ci.value]
end

function MOI.get(optimizer::Optimizer, ::MOI.ResultCount)
    if isnothing(optimizer.result)
        return 0
    else
        return 1
    end
end
