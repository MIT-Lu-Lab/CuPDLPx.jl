# cuPDLPx.jl
Julia interface for cuPDLPx.

## Use with JuMP

To use cuPDLPx with JuMP, use `cuPDLPx.Optimizer`:

```julia
using JuMP, cuPDLPx
model = Model(cuPDLPx.Optimizer)
```

## Setting solver parameters

cuPDLPx.jl supports setting solver parameters via `set_optimizer_attribute`.

```Julia
using JuMP
using cuPDLPx

model = read_from_file("2club200v15p5scn.mps.gz")
undo = relax_integrality(model)

println("Read MPS succeed.")
set_optimizer(model, cuPDLPx.Optimizer)

set_optimizer_attribute(model, "verbose", true)
set_optimizer_attribute(model, "l_inf_ruiz_iterations", 0)
set_optimizer_attribute(model, "iteration_limit", 200)

optimize!(model)
println(solution_summary(model))
```
## Supported parameters

All of the following attributes are supported.

### PDHG parameters

| name | type | default |
|---|---|---|
| `l_inf_ruiz_iterations` | `Int` | `10` |
| `has_pock_chambolle_alpha` | `Bool` | `true` |
| `pock_chambolle_alpha` | `Float64` | `1.0` |
| `bound_objective_rescaling` | `Bool` | `true` |
| `verbose` | `Bool` | `false` |
| `termination_evaluation_frequency` | `Int` | `200` |
| `sv_max_iter` | `Int` | `5000` |
| `sv_tol` | `Float64` | `1e-4` |
| `reflection_coefficient` | `Float64` | `1.0` |
| `feasibility_polishing` | `Bool` | `false` |
| `presolve` | `Bool` | `true` |
| `artificial_restart_threshold` | `Float64` | `0.36` |
| `sufficient_reduction_for_restart` | `Float64` | `0.2` |
| `necessary_reduction_for_restart` | `Float64` | `0.5` |
| `k_p` | `Float64` | `0.99` |
| `k_i` | `Float64` | `0.01` |
| `k_d` | `Float64` | `0.0` |
| `i_smooth` | `Float64` | `0.3` |

### Termination criteria

| name | type | default |
|---|---|---|
| `eps_optimal_relative` | `Float64` | `1e-4` |
| `eps_feasible_relative` | `Float64` | `1e-4` |
| `eps_feas_polish_relative` | `Float64` | `1e-6` |
| `eps_infeasible` | `Float64` | `1e-10` |
| `time_sec_limit` | `Float64` | `3600.0` |
| `iteration_limit` | `Int` | `INT32_MAX` |
