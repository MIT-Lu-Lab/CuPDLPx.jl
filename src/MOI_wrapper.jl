import MathOptInterface as MOI

const Lib = cuPDLPx.LibcuPDLPx

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
        MOI.Utilities.MutableSparseMatrixCSC{Cdouble,Cint,MOI.Utilities.ZeroBasedIndexing},
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

Create a new cuPDLPx optimizer.
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    result::Union{Nothing,Lib.cupdlpx_result_t}
    parameters::Lib.pdhg_parameters_t
    sets::Union{Nothing,_LPProductOfSets{Cdouble}}
    max_sense::Bool
    silent::Bool

    function Optimizer()
        params_ref = Ref{Lib.pdhg_parameters_t}()
        Lib.set_default_parameters(
            Base.unsafe_convert(Ptr{Lib.pdhg_parameters_t}, params_ref),
        )

        return new(nothing, params_ref[], nothing, false, false)
    end
end

function MOI.default_cache(::Optimizer, ::Type)
    return OptimizerCache()
end

# ====================
#   Helper: Immutable Update
# ====================
function _update_immutable(obj::T, field::Symbol, value) where {T}
    args = map(fieldnames(T)) do f
        f == field ? value : getfield(obj, f)
    end
    return T(args...)
end

# ====================
#   Parameters
# ====================

MOI.get(::Optimizer, ::MOI.SolverName) = "cuPDLPx"

function MOI.supports(::Optimizer, param::MOI.RawOptimizerAttribute)
    return hasfield(Lib.pdhg_parameters_t, Symbol(param.name))
end

function MOI.set(optimizer::Optimizer, param::MOI.RawOptimizerAttribute, value)
    if !MOI.supports(optimizer, param)
        throw(MOI.UnsupportedAttribute(param))
    end
    optimizer.parameters =
        _update_immutable(optimizer.parameters, Symbol(param.name), value)
    return
end

function MOI.get(optimizer::Optimizer, param::MOI.RawOptimizerAttribute)
    if !MOI.supports(optimizer, param)
        throw(MOI.UnsupportedAttribute(param))
    end
    return getfield(optimizer.parameters, Symbol(param.name))
end

MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
function MOI.set(optimizer::Optimizer, ::MOI.TimeLimitSec, value::Real)
    current_criteria = optimizer.parameters.termination_criteria
    new_criteria = _update_immutable(current_criteria, :time_sec_limit, Float64(value))
    optimizer.parameters =
        _update_immutable(optimizer.parameters, :termination_criteria, new_criteria)
    return
end

function MOI.get(optimizer::Optimizer, ::MOI.TimeLimitSec)
    return optimizer.parameters.termination_criteria.time_sec_limit
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
function MOI.set(optimizer::Optimizer, ::MOI.Silent, value::Bool)
    optimizer.silent = value
    new_verbose = value ? 0 : 1
    optimizer.parameters = _update_immutable(optimizer.parameters, :verbose, new_verbose)
    return
end
MOI.get(optimizer::Optimizer, ::MOI.Silent) = optimizer.silent

# ====================
#   Empty & Status
# ====================

function MOI.is_empty(optimizer::Optimizer)
    return isnothing(optimizer.result)
end

function MOI.empty!(optimizer::Optimizer)
    optimizer.result = nothing
    optimizer.sets = nothing
    return
end

# ========================================
#   Constraints & Objectives
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
#   Optimize
# ===============================

function _flip_sense(optimizer::Optimizer, obj)
    return optimizer.max_sense ? -obj : obj
end

function create_matrix_desc_ref(
    A::MOI.Utilities.MutableSparseMatrixCSC{Cdouble,Cint,MOI.Utilities.ZeroBasedIndexing},
)
    A_csc = Lib.MatrixCSC(
        length(A.rowval),
        pointer(A.colptr),
        pointer(A.rowval),
        pointer(A.nzval),
    )

    desc_ref = Ref{Lib.matrix_desc_t}()

    desc_val = Lib.matrix_desc_t(ntuple(_ -> UInt8(0), 56))
    desc_ref[] = desc_val

    desc_ptr = Base.unsafe_convert(Ptr{Lib.matrix_desc_t}, desc_ref)

    desc_ptr.m = Cint(A.m)
    desc_ptr.n = Cint(A.n)
    desc_ptr.fmt = Lib.matrix_csc
    desc_ptr.zero_tolerance = 1e-12
    desc_ptr.data.csc = A_csc

    return desc_ref
end

function MOI.optimize!(dest::Optimizer, src::OptimizerCache)
    MOI.empty!(dest)
    if src.constraints.coefficients.n == 0
        dest.result = nothing
        return MOI.Utilities.identity_index_map(src), false
    end

    dest.max_sense = MOI.get(src, MOI.ObjectiveSense()) == MOI.MAX_SENSE
    obj = MOI.get(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())

    c = zeros(Cdouble, src.constraints.coefficients.n)
    for term in obj.terms
        c[term.variable.value] += _flip_sense(dest, term.coefficient)
    end
    obj_const = [_flip_sense(dest, MOI.constant(obj))]

    dest.sets = src.constraints.sets

    matrix_desc_ref = create_matrix_desc_ref(src.constraints.coefficients)

    matrix_desc_ptr = Base.unsafe_convert(Ptr{Lib.matrix_desc_t}, matrix_desc_ref)

    prob = Lib.create_lp_problem(
        pointer(c),
        matrix_desc_ptr,
        pointer(src.constraints.constants.lower),
        pointer(src.constraints.constants.upper),
        pointer(src.variables.lower),
        pointer(src.variables.upper),
        pointer(obj_const),
    )
    @assert prob != C_NULL

    params_ref = Ref(dest.parameters)
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

# ====================
#   Result Getters
# ====================

function MOI.get(optimizer::Optimizer, ::MOI.SolveTimeSec)
    return optimizer.result.cumulative_time_sec
end

function MOI.get(optimizer::Optimizer, ::MOI.RawStatusString)
    return isnothing(optimizer.result) ? "Optimize not called" : "Solver finished"
end

const _TERMINATION_STATUS_MAP = Dict(
    Lib.TERMINATION_REASON_UNSPECIFIED => MOI.OPTIMIZE_NOT_CALLED,
    Lib.TERMINATION_REASON_OPTIMAL => MOI.OPTIMAL,
    Lib.TERMINATION_REASON_PRIMAL_INFEASIBLE => MOI.INFEASIBLE,
    Lib.TERMINATION_REASON_DUAL_INFEASIBLE => MOI.DUAL_INFEASIBLE,
    Lib.TERMINATION_REASON_TIME_LIMIT => MOI.TIME_LIMIT,
    Lib.TERMINATION_REASON_ITERATION_LIMIT => MOI.ITERATION_LIMIT,
    Lib.TERMINATION_REASON_FEAS_POLISH_SUCCESS => MOI.OTHER_ERROR,
)

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return isnothing(optimizer.result) ? MOI.OPTIMIZE_NOT_CALLED :
           _TERMINATION_STATUS_MAP[optimizer.result.termination_reason]
end

function MOI.get(optimizer::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(optimizer, attr)
    return _flip_sense(optimizer, optimizer.result.primal_objective_value)
end

function MOI.get(optimizer::Optimizer, attr::MOI.DualObjectiveValue)
    MOI.check_result_index_bounds(optimizer, attr)
    return _flip_sense(optimizer, optimizer.result.dual_objective_value)
end

const _PRIMAL_STATUS_MAP = Dict(
    Lib.TERMINATION_REASON_UNSPECIFIED => MOI.NO_SOLUTION,
    Lib.TERMINATION_REASON_OPTIMAL => MOI.FEASIBLE_POINT,
    Lib.TERMINATION_REASON_PRIMAL_INFEASIBLE => MOI.NO_SOLUTION,
    Lib.TERMINATION_REASON_DUAL_INFEASIBLE => MOI.INFEASIBILITY_CERTIFICATE,
    Lib.TERMINATION_REASON_TIME_LIMIT => MOI.UNKNOWN_RESULT_STATUS,
    Lib.TERMINATION_REASON_ITERATION_LIMIT => MOI.UNKNOWN_RESULT_STATUS,
    Lib.TERMINATION_REASON_FEAS_POLISH_SUCCESS => MOI.UNKNOWN_RESULT_STATUS,
)

const _DUAL_STATUS_MAP = Dict(
    LibcuPDLPx.TERMINATION_REASON_UNSPECIFIED => MOI.NO_SOLUTION,
    LibcuPDLPx.TERMINATION_REASON_OPTIMAL => MOI.FEASIBLE_POINT,
    LibcuPDLPx.TERMINATION_REASON_PRIMAL_INFEASIBLE => MOI.INFEASIBILITY_CERTIFICATE,
    LibcuPDLPx.TERMINATION_REASON_DUAL_INFEASIBLE => MOI.NO_SOLUTION,
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

function MOI.get(optimizer::Optimizer, attr::MOI.VariablePrimal, vi::MOI.VariableIndex)
    MOI.check_result_index_bounds(optimizer, attr)
    return unsafe_load(optimizer.result.primal_solution, vi.value)
end

function MOI.get(optimizer::Optimizer, attr::MOI.DualStatus)
    if attr.result_index > MOI.get(optimizer, MOI.ResultCount())
        return MOI.NO_SOLUTION
    end
    return _DUAL_STATUS_MAP[optimizer.result.termination_reason]
end

function MOI.get(
    optimizer::Optimizer,
    attr::MOI.ConstraintDual,
    ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}},
)
    MOI.check_result_index_bounds(optimizer, attr)
    row = only(MOI.Utilities.rows(optimizer.sets, ci))
    return unsafe_load(optimizer.result.dual_solution, row)
end

function MOI.get(optimizer::Optimizer, ::MOI.ResultCount)
    return isnothing(optimizer.result) ? 0 : 1
end
