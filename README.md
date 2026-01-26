# CuPDLPx.jl
[![version](https://juliahub.com/docs/General/CuPDLPx/stable/version.svg)](https://juliahub.com/ui/Packages/General/CuPDLPx)

Julia interface for [cuPDLPx](https://github.com/MIT-Lu-Lab/cuPDLPx).

## Installation
CuPDLPx.jl is available from the Julia General registry:

```julia
pkg> add CuPDLPx
```

## Use with JuMP

To use CuPDLPx with JuMP, use `CuPDLPx.Optimizer`:

```julia
using JuMP, CuPDLPx
model = Model(CuPDLPx.Optimizer)
```

## Setting solver parameters

CuPDLPx.jl supports setting solver parameters via `set_optimizer_attribute`.

```Julia
using JuMP
using CuPDLPx

model = read_from_file("2club200v15p5scn.mps.gz")
undo = relax_integrality(model)

println("Read MPS succeed.")
set_optimizer(model, CuPDLPx.Optimizer)

set_optimizer_attribute(model, "verbose", true)
set_optimizer_attribute(model, "l_inf_ruiz_iterations", 0)
set_optimizer_attribute(model, "iteration_limit", 200)

optimize!(model)
println(solution_summary(model))
```
## Supported parameters

All of the following attributes are supported.

### 1. Termination criteria

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `eps_optimal_relative` | `Float64` | `1e-4` | Relative tolerance for optimality gap. |
| `eps_feasible_relative` | `Float64` | `1e-4` | Relative tolerance for primal and dual feasibility. |
| `eps_feas_polish_relative` | `Float64` | `1e-6` | Relative tolerance used during the polishing phase. |
| `time_sec_limit` | `Float64` | `3600.0` | Maximum runtime allowed in seconds. |
| `iteration_limit` | `Int32` | `2147483647` | Maximum number of iterations. |
| `optimality_norm` | `norm_type_t` | `NORM_TYPE_L2` | Norm used to measure residuals: `NORM_TYPE_L2` (0) or `NORM_TYPE_L_INF` (1). |
| `termination_evaluation_frequency` | `Int` | `200` | Frequency (in iterations) at which to check termination criteria. |

### 2. Algorithm and Preconditioning

| `presolve` | `Bool` | `true` | Whether to enable the PSLP presolver. |
| `l_inf_ruiz_iterations` | `Int` | `10` | Number of Ruiz rescaling iterations. |
| `has_pock_chambolle_alpha` | `Bool` | `true` | Whether to use Pock-Chambolle rescaling. |
| `pock_chambolle_alpha` | `Float64` | `1.0` | $\alpha$ used in Pock-Chambolle rescaling. |
| `bound_objective_rescaling` | `Bool` | `true` | Whether to use objective and bound rescaling. |
| `reflection_coefficient` | `Float64` | `1.0` | Reflection coefficient (typically in $[0, 1]$). |
| `feasibility_polishing` | `Bool` | `false` | Wheather to perform post-solve feasibility polishing. |
| `sv_max_iter` | `Int` | `5000` | Maximum iterations for singular value estimation. |
| `sv_tol` | `Float64` | `1e-4` | Tolerance for singular value estimation. |
| `verbose` | `Bool` | `false` | Whether to enable console output and progress logging. |

### 3. Adaptive Restart and Primal Weight

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `artificial_restart_threshold` | `Float64` | `0.36` | Threshold for triggering a forced "artificial" restart (based on iterations). |
| `sufficient_reduction_for_restart` | `Float64` | `0.2` | Threshold for sufficient decay in fixed-point error to trigger a restart. |
| `necessary_reduction_for_restart` | `Float64` | `0.8` | Threshold for necessary decay in fixed-point error to trigger a restart. |
| `k_p` | `Float64` | `0.99` | Proportional gain for the primal weight (PID) controller. |
| `k_i` | `Float64` | `0.01` | Integral gain for the primal weight (PID) controller. |
| `k_d` | `Float64` | `0.0` | Derivative gain for the primal weight (PID) controller. |
| `i_smooth` | `Float64` | `0.3` | Smoothing factor for the integral component of the controller. |
