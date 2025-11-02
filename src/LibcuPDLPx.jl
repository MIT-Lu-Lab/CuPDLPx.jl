module LibcuPDLPx

using cuPDLPx_jll
export cuPDLPx_jll

const cublasStatus_t = Cint

const cusparseStatus_t = Cint

mutable struct cusparseContext end

const cusparseHandle_t = Ptr{cusparseContext}

mutable struct cublasContext end

const cublasHandle_t = Ptr{cublasContext}

struct cu_sparse_matrix_csr_t
    num_rows::Cint
    num_cols::Cint
    num_nonzeros::Cint
    row_ptr::Ptr{Cint}
    col_ind::Ptr{Cint}
    val::Ptr{Cdouble}
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
end

@enum termination_reason_t::UInt32 begin
    TERMINATION_REASON_UNSPECIFIED = 0x0000000000000000
    TERMINATION_REASON_OPTIMAL = 0x0000000000000001
    TERMINATION_REASON_PRIMAL_INFEASIBLE = 0x0000000000000002
    TERMINATION_REASON_DUAL_INFEASIBLE = 0x0000000000000003
    TERMINATION_REASON_TIME_LIMIT = 0x0000000000000004
    TERMINATION_REASON_ITERATION_LIMIT = 0x0000000000000005
end

struct rescale_info_t
    scaled_problem::Ptr{lp_problem_t}
    con_rescale::Ptr{Cdouble}
    var_rescale::Ptr{Cdouble}
    con_bound_rescale::Cdouble
    obj_vec_rescale::Cdouble
    rescaling_time_sec::Cdouble
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

struct pdhg_solver_state_t
    num_variables::Cint
    num_constraints::Cint
    variable_lower_bound::Ptr{Cdouble}
    variable_upper_bound::Ptr{Cdouble}
    objective_vector::Ptr{Cdouble}
    objective_constant::Cdouble
    constraint_matrix::Ptr{cu_sparse_matrix_csr_t}
    constraint_matrix_t::Ptr{cu_sparse_matrix_csr_t}
    constraint_lower_bound::Ptr{Cdouble}
    constraint_upper_bound::Ptr{Cdouble}
    num_blocks_primal::Cint
    num_blocks_dual::Cint
    num_blocks_primal_dual::Cint
    objective_vector_norm::Cdouble
    constraint_bound_norm::Cdouble
    constraint_lower_bound_finite_val::Ptr{Cdouble}
    constraint_upper_bound_finite_val::Ptr{Cdouble}
    variable_lower_bound_finite_val::Ptr{Cdouble}
    variable_upper_bound_finite_val::Ptr{Cdouble}
    initial_primal_solution::Ptr{Cdouble}
    current_primal_solution::Ptr{Cdouble}
    pdhg_primal_solution::Ptr{Cdouble}
    reflected_primal_solution::Ptr{Cdouble}
    dual_product::Ptr{Cdouble}
    initial_dual_solution::Ptr{Cdouble}
    current_dual_solution::Ptr{Cdouble}
    pdhg_dual_solution::Ptr{Cdouble}
    reflected_dual_solution::Ptr{Cdouble}
    primal_product::Ptr{Cdouble}
    step_size::Cdouble
    primal_weight::Cdouble
    total_count::Cint
    is_this_major_iteration::Bool
    primal_weight_error_sum::Cdouble
    primal_weight_last_error::Cdouble
    best_primal_weight::Cdouble
    best_primal_dual_residual_gap::Cdouble
    constraint_rescaling::Ptr{Cdouble}
    variable_rescaling::Ptr{Cdouble}
    constraint_bound_rescaling::Cdouble
    objective_vector_rescaling::Cdouble
    primal_slack::Ptr{Cdouble}
    dual_slack::Ptr{Cdouble}
    rescaling_time_sec::Cdouble
    cumulative_time_sec::Cdouble
    primal_residual::Ptr{Cdouble}
    absolute_primal_residual::Cdouble
    relative_primal_residual::Cdouble
    dual_residual::Ptr{Cdouble}
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
    delta_primal_solution::Ptr{Cdouble}
    delta_dual_solution::Ptr{Cdouble}
    fixed_point_error::Cdouble
    initial_fixed_point_error::Cdouble
    last_trial_fixed_point_error::Cdouble
    inner_count::Cint
    sparse_handle::cusparseHandle_t
    blas_handle::cublasHandle_t
    spmv_buffer_size::Csize_t
    primal_spmv_buffer_size::Csize_t
    dual_spmv_buffer_size::Csize_t
    primal_spmv_buffer::Ptr{Cvoid}
    dual_spmv_buffer::Ptr{Cvoid}
    spmv_buffer::Ptr{Cvoid}
    matA::Cint
    matAt::Cint
    vec_primal_sol::Cint
    vec_dual_sol::Cint
    vec_primal_prod::Cint
    vec_dual_prod::Cint
    ones_primal_d::Ptr{Cdouble}
    ones_dual_d::Ptr{Cdouble}
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
    matrix_dense = 0x0000000000000000
    matrix_csr = 0x0000000000000001
    matrix_csc = 0x0000000000000002
    matrix_coo = 0x0000000000000003
end

struct var"##Ctag#231"
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{var"##Ctag#231"}, f::Symbol)
    f === :dense && return Ptr{var"##Ctag#232"}(x + 0)
    f === :csr && return Ptr{var"##Ctag#233"}(x + 0)
    f === :csc && return Ptr{var"##Ctag#234"}(x + 0)
    f === :coo && return Ptr{var"##Ctag#235"}(x + 0)
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

function Base.propertynames(x::var"##Ctag#231", private::Bool = false)
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
    f === :data && return Ptr{var"##Ctag#231"}(x + 24)
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

function safe_malloc(size)
    ccall((:safe_malloc, libcupdlpx), Ptr{Cvoid}, (Csize_t,), size)
end

function safe_calloc(num, size)
    ccall((:safe_calloc, libcupdlpx), Ptr{Cvoid}, (Csize_t, Csize_t), num, size)
end

function safe_realloc(ptr, new_size)
    ccall((:safe_realloc, libcupdlpx), Ptr{Cvoid}, (Ptr{Cvoid}, Csize_t), ptr, new_size)
end

function estimate_maximum_singular_value(sparse_handle, blas_handle, A, AT, max_iterations, tolerance)
    ccall((:estimate_maximum_singular_value, libcupdlpx), Cdouble, (cusparseHandle_t, cublasHandle_t, Ptr{cu_sparse_matrix_csr_t}, Ptr{cu_sparse_matrix_csr_t}, Cint, Cdouble), sparse_handle, blas_handle, A, AT, max_iterations, tolerance)
end

function compute_interaction_and_movement(solver_state, interaction, movement)
    ccall((:compute_interaction_and_movement, libcupdlpx), Cvoid, (Ptr{pdhg_solver_state_t}, Ptr{Cdouble}, Ptr{Cdouble}), solver_state, interaction, movement)
end

function should_do_adaptive_restart(solver_state, restart_params, termination_evaluation_frequency)
    ccall((:should_do_adaptive_restart, libcupdlpx), Bool, (Ptr{pdhg_solver_state_t}, Ptr{restart_parameters_t}, Cint), solver_state, restart_params, termination_evaluation_frequency)
end

function check_termination_criteria(solver_state, criteria)
    ccall((:check_termination_criteria, libcupdlpx), Cvoid, (Ptr{pdhg_solver_state_t}, Ptr{termination_criteria_t}), solver_state, criteria)
end

function print_initial_info(params, problem)
    ccall((:print_initial_info, libcupdlpx), Cvoid, (Ptr{pdhg_parameters_t}, Ptr{lp_problem_t}), params, problem)
end

function pdhg_final_log(solver_state, verbose, termination_reason)
    ccall((:pdhg_final_log, libcupdlpx), Cvoid, (Ptr{pdhg_solver_state_t}, Bool, termination_reason_t), solver_state, verbose, termination_reason)
end

function display_iteration_stats(solver_state, verbose)
    ccall((:display_iteration_stats, libcupdlpx), Cvoid, (Ptr{pdhg_solver_state_t}, Bool), solver_state, verbose)
end

function termination_reason_to_string(reason)
    ccall((:termination_reason_to_string, libcupdlpx), Ptr{Cchar}, (termination_reason_t,), reason)
end

function get_print_frequency(iter)
    ccall((:get_print_frequency, libcupdlpx), Cint, (Cint,), iter)
end

function compute_residual(state)
    ccall((:compute_residual, libcupdlpx), Cvoid, (Ptr{pdhg_solver_state_t},), state)
end

function compute_infeasibility_information(state)
    ccall((:compute_infeasibility_information, libcupdlpx), Cvoid, (Ptr{pdhg_solver_state_t},), state)
end

function read_mps_file(filename)
    ccall((:read_mps_file, libcupdlpx), Ptr{lp_problem_t}, (Ptr{Cchar},), filename)
end

function lp_problem_free(L)
    ccall((:lp_problem_free, libcupdlpx), Cvoid, (Ptr{lp_problem_t},), L)
end

function rescale_problem(params, original_problem)
    ccall((:rescale_problem, libcupdlpx), Ptr{rescale_info_t}, (Ptr{pdhg_parameters_t}, Ptr{lp_problem_t}), params, original_problem)
end

function optimize(params, original_problem)
    ccall((:optimize, libcupdlpx), Ptr{cupdlpx_result_t}, (Ptr{pdhg_parameters_t}, Ptr{lp_problem_t}), params, original_problem)
end

function cupdlpx_result_free(results)
    ccall((:cupdlpx_result_free, libcupdlpx), Cvoid, (Ptr{cupdlpx_result_t},), results)
end

function set_default_parameters(params)
    ccall((:set_default_parameters, libcupdlpx), Cvoid, (Ptr{pdhg_parameters_t},), params)
end

struct var"##Ctag#232"
    A::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#232"}, f::Symbol)
    f === :A && return Ptr{Ptr{Cdouble}}(x + 0)
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
    row_ptr::Ptr{Cint}
    col_ind::Ptr{Cint}
    vals::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#233"}, f::Symbol)
    f === :nnz && return Ptr{Cint}(x + 0)
    f === :row_ptr && return Ptr{Ptr{Cint}}(x + 8)
    f === :col_ind && return Ptr{Ptr{Cint}}(x + 16)
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
    col_ptr::Ptr{Cint}
    row_ind::Ptr{Cint}
    vals::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#234"}, f::Symbol)
    f === :nnz && return Ptr{Cint}(x + 0)
    f === :col_ptr && return Ptr{Ptr{Cint}}(x + 8)
    f === :row_ind && return Ptr{Ptr{Cint}}(x + 16)
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

struct var"##Ctag#235"
    nnz::Cint
    row_ind::Ptr{Cint}
    col_ind::Ptr{Cint}
    vals::Ptr{Cdouble}
end
function Base.getproperty(x::Ptr{var"##Ctag#235"}, f::Symbol)
    f === :nnz && return Ptr{Cint}(x + 0)
    f === :row_ind && return Ptr{Ptr{Cint}}(x + 8)
    f === :col_ind && return Ptr{Ptr{Cint}}(x + 16)
    f === :vals && return Ptr{Ptr{Cdouble}}(x + 24)
    return getfield(x, f)
end

function Base.getproperty(x::var"##Ctag#235", f::Symbol)
    r = Ref{var"##Ctag#235"}(x)
    ptr = Base.unsafe_convert(Ptr{var"##Ctag#235"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"##Ctag#235"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

const THREADS_PER_BLOCK = 256

end # module
