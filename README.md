# CuPDLPx.jl

[![version](https://juliahub.com/docs/General/CuPDLPx/stable/version.svg)](https://juliahub.com/ui/Packages/General/CuPDLPx)

[CuPDLPx.jl](https://github.com/MIT-Lu-Lab/CuPDLPx.jl) is a wrapper for the
[cuPDLPx](https://github.com/MIT-Lu-Lab/cuPDLPx) solver.

It has two components:

 - a thin wrapper around the complete C API
 - an interface to [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl)

## Getting help

If you need help, please ask a question on the [JuMP community forum](https://jump.dev/forum).

If you have a reproducible example of a bug, please [open a GitHub issue](https://github.com/MIT-Lu-Lab/CuPDLPx.jl/issues/new).

## License

`CuPDLPx.jl` is licensed under the [Apache 2.0](https://github.com/MIT-Lu-Lab/CuPDLPx.jl/blob/main/LICENSE).

The underlying solver, [MIT-Lu-Lab/cuPDLPx](https://github.com/MIT-Lu-Lab/cuPDLPx), is
licensed under the [MIT license](https://github.com/MIT-Lu-Lab/cuPDLPx/blob/main/LICENSE).

## Installation

Install CuPDLPx as follows:
```julia
import Pkg
Pkg.add("CuPDLPx")
```

In addition to installing the CuPDLPx.jl package, this will also download and
install the cuPDLPx binaries. You do not need to install cuPDLPx separately.

## Use with JuMP

To use CuPDLPx with JuMP, use `CuPDLPx.Optimizer`:

```julia
using JuMP, CuPDLPx
model = Model(CuPDLPx.Optimizer)
set_attribute(model, "verbose", true)
set_attribute(model, "l_inf_ruiz_iterations", 0)
set_attribute(model, "iteration_limit", 200)
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

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `presolve` | `Bool` | `true` | Whether to enable the PSLP presolver. |
| `l_inf_ruiz_iterations` | `Int` | `10` | Number of Ruiz rescaling iterations. |
| `has_pock_chambolle_alpha` | `Bool` | `true` | Whether to use Pock-Chambolle rescaling. |
| `pock_chambolle_alpha` | `Float64` | `1.0` | $\alpha$ used in Pock-Chambolle rescaling. |
| `bound_objective_rescaling` | `Bool` | `true` | Whether to use objective and bound rescaling. |
| `reflection_coefficient` | `Float64` | `1.0` | Reflection coefficient (typically in $[0, 1]$). |
| `feasibility_polishing` | `Bool` | `false` | Whether to perform post-solve feasibility polishing. |
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
