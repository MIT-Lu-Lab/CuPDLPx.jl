# cuPDLPx.jl
Julia interface for cuPDLPx.

## Use with JuMP

To use cuPDLPx with JuMP, use `cuPDLPx.Optimizer`:

```julia
using JuMP, cuPDLPx
model = Model(cuPDLPx.Optimizer)
```
