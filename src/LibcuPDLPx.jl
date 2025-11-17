module LibcuPDLPx

using cuPDLPx_jll
export cuPDLPx_jll

@enum termination_reason_t::UInt32 begin
    TERMINATION_REASON_UNSPECIFIED = 0
    TERMINATION_REASON_OPTIMAL = 1
    TERMINATION_REASON_PRIMAL_INFEASIBLE = 2
    TERMINATION_REASON_DUAL_INFEASIBLE = 3
    TERMINATION_REASON_TIME_LIMIT = 4
    TERMINATION_REASON_ITERATION_LIMIT = 5
end

struct lp_problem_t
    num_variables::Cint
    num_constraints::Cint
    variable_lower_bound::Ptr{Cdouble}
    variable_upper_bound::Ptr{Cdouble}
    objective_vector::Ptr{Cdouble}
    objective_constant::Cdouble
    constraint_matrix_row_pointers::Ptr{Cint}
    constraint_matrix_col_indices::Ptr{Cint}
    constraint_matrix_values::Ptr{Cdouble}
    constraint_matrix_num_nonzeros::Cint
    constraint_lower_bound::Ptr{Cdouble}
    constraint_upper_bound::Ptr{Cdouble}
    primal_start::Ptr{Cdouble}
    dual_start::Ptr{Cdouble}
end

struct restart_parameters_t
    artificial_restart_threshold::Cdouble
    sufficient_reduction_for_restart::Cdouble
    necessary_reduction_for_restart::Cdouble
    k_p::Cdouble
    k_i::Cdouble
    k_d::Cdouble
    i_smooth::Cdouble
end

struct termination_criteria_t
    eps_optimal_relative::Cdouble
    eps_feasible_relative::Cdouble
    eps_infeasible::Cdouble
    time_sec_limit::Cdouble
    iteration_limit::Cint
end

struct pdhg_parameters_t
    l_inf_ruiz_iterations::Cint
    has_pock_chambolle_alpha::Bool
    pock_chambolle_alpha::Cdouble
    bound_objective_rescaling::Bool
    verbose::Bool
    termination_evaluation_frequency::Cint
    termination_criteria::termination_criteria_t
    restart_params::restart_parameters_t
    reflection_coefficient::Cdouble
end

struct cupdlpx_result_t
    num_variables::Cint
    num_constraints::Cint
    primal_solution::Ptr{Cdouble}
    dual_solution::Ptr{Cdouble}
    total_count::Cint
    rescaling_time_sec::Cdouble
    cumulative_time_sec::Cdouble
    absolute_primal_residual::Cdouble
    relative_primal_residual::Cdouble
    absolute_dual_residual::Cdouble
    relative_dual_residual::Cdouble
    primal_objective_value::Cdouble
    dual_objective_value::Cdouble
    objective_gap::Cdouble
    relative_objective_gap::Cdouble
    max_primal_ray_infeasibility::Cdouble
    max_dual_ray_infeasibility::Cdouble
    primal_ray_linear_objective::Cdouble
    dual_ray_objective::Cdouble
    termination_reason::termination_reason_t
end

@enum matrix_format_t::UInt32 begin
    matrix_dense = 0
    matrix_csr = 1
    matrix_csc = 2
    matrix_coo = 3
end

struct var"##Ctag#230"
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{var"##Ctag#230"}, f::Symbol)
    f === :dense && return Ptr{var"##Ctag#231"}(x + 0)
    f === :csr && return Ptr{var"##Ctag#232"}(x + 0)
    f === :csc && return Ptr{var"##Ctag#233"}(x + 0)
    f === :coo && return Ptr{var"##Ctag#234"}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#230", f::Symbol)
    r = Ref{var"##Ctag#230"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#230"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#230"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::var"##Ctag#230", private::Bool = false)
    (:dense, :csr, :csc, :coo, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

struct matrix_desc_t
    data::NTuple{56, UInt8}
end

function Base.getproperty(x::Ptr{matrix_desc_t}, f::Symbol)
    f === :m && return Ptr{Cint}(x + 0)
    f === :n && return Ptr{Cint}(x + 4)
    f === :fmt && return Ptr{matrix_format_t}(x + 8)
    f === :zero_tolerance && return Ptr{Cdouble}(x + 16)
    f === :data && return Ptr{var"##Ctag#230"}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::matrix_desc_t, f::Symbol)
    r = Ref{matrix_desc_t}(x)
    ptr = Base.unsafe_convert(Ptr{matrix_desc_t}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{matrix_desc_t}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

function Base.propertynames(x::matrix_desc_t, private::Bool = false)
    (:m, :n, :fmt, :zero_tolerance, :data, if private
            fieldnames(typeof(x))
        else
            ()
        end...)
end

function create_lp_problem(objective_c, A_desc, con_lb, con_ub, var_lb, var_ub, objective_constant)
    ccall((:create_lp_problem, libcupdlpx), Ptr{lp_problem_t}, (Ptr{Cdouble}, Ptr{matrix_desc_t}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), objective_c, A_desc, con_lb, con_ub, var_lb, var_ub, objective_constant)
end

function set_start_values(prob, primal, dual)
    ccall((:set_start_values, libcupdlpx), Cvoid, (Ptr{lp_problem_t}, Ptr{Cdouble}, Ptr{Cdouble}), prob, primal, dual)
end

function solve_lp_problem(prob, params)
    ccall((:solve_lp_problem, libcupdlpx), Ptr{cupdlpx_result_t}, (Ptr{lp_problem_t}, Ptr{pdhg_parameters_t}), prob, params)
end

function set_default_parameters(params)
    ccall((:set_default_parameters, libcupdlpx), Cvoid, (Ptr{pdhg_parameters_t},), params)
end

function cupdlpx_result_free(results)
    ccall((:cupdlpx_result_free, libcupdlpx), Cvoid, (Ptr{cupdlpx_result_t},), results)
end

function lp_problem_free(prob)
    ccall((:lp_problem_free, libcupdlpx), Cvoid, (Ptr{lp_problem_t},), prob)
end

struct var"##Ctag#231"
    A::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#231"}, f::Symbol)
    f === :A && return Ptr{Ptr{Cdouble}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#231", f::Symbol)
    r = Ref{var"##Ctag#231"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#231"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#231"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end


struct var"##Ctag#232"
    nnz::Cint
    row_ptr::Ptr{Cint}
    col_ind::Ptr{Cint}
    vals::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#232"}, f::Symbol)
    f === :nnz && return Ptr{Cint}(x + 0)
    f === :row_ptr && return Ptr{Ptr{Cint}}(x + 8)
    f === :col_ind && return Ptr{Ptr{Cint}}(x + 16)
    f === :vals && return Ptr{Ptr{Cdouble}}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#232", f::Symbol)
    r = Ref{var"##Ctag#232"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#232"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#232"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end


struct var"##Ctag#233"
    nnz::Cint
    col_ptr::Ptr{Cint}
    row_ind::Ptr{Cint}
    vals::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#233"}, f::Symbol)
    f === :nnz && return Ptr{Cint}(x + 0)
    f === :col_ptr && return Ptr{Ptr{Cint}}(x + 8)
    f === :row_ind && return Ptr{Ptr{Cint}}(x + 16)
    f === :vals && return Ptr{Ptr{Cdouble}}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#233", f::Symbol)
    r = Ref{var"##Ctag#233"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#233"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#233"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end


struct var"##Ctag#234"
    nnz::Cint
    row_ind::Ptr{Cint}
    col_ind::Ptr{Cint}
    vals::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#234"}, f::Symbol)
    f === :nnz && return Ptr{Cint}(x + 0)
    f === :row_ind && return Ptr{Ptr{Cint}}(x + 8)
    f === :col_ind && return Ptr{Ptr{Cint}}(x + 16)
    f === :vals && return Ptr{Ptr{Cdouble}}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#234", f::Symbol)
    r = Ref{var"##Ctag#234"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#234"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#234"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end


end # module
