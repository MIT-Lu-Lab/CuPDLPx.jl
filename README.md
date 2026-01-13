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

| name | type |
|---|---|
| `l_inf_ruiz_iterations` | `Int` |
| `has_pock_chambolle_alpha` | `Bool` |
| `pock_chambolle_alpha` | `Float64` |
| `bound_objective_rescaling` | `Bool` |
| `verbose` | `Bool` |
| `termination_evaluation_frequency` | `Int` |
| `sv_max_iter` | `Int` |
| `sv_tol` | `Float64` |
| `reflection_coefficient` | `Float64` |
| `feasibility_polishing` | `Bool` |
| `presolve` | `Bool` |
| `artificial_restart_threshold` | `Float64` |
| `sufficient_reduction_for_restart` | `Float64` |
| `necessary_reduction_for_restart` | `Float64` |
| `k_p` | `Float64` |
| `k_i` | `Float64` |
| `k_d` | `Float64` |
| `i_smooth` | `Float64` |

### Termination criteria

| name | type |
|---|---|
| `eps_optimal_relative` | `Float64` |
| `eps_feasible_relative` | `Float64` |
| `eps_feas_polish_relative` | `Float64` |
| `eps_infeasible` | `Float64` |
| `time_sec_limit` | `Float64` |
| `iteration_limit` | `Int` |
