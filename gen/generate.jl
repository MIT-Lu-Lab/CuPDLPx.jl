using Clang.Generators
import cuPDLPx_jll
import CUDA_SDK_jll

include_dirs = [
    joinpath(cuPDLPx_jll.artifact_dir, "include"),
    joinpath(CUDA_SDK_jll.artifact_dir, "include"),
]

headers = [
    joinpath(include_dirs[1], "cupdlpx.h"),
    joinpath(include_dirs[1], "mps_parser.h"),
]

args = vcat(get_default_args(), ["-I$(d)" for d in include_dirs]...)

options = load_options(joinpath(@__DIR__, "generate.toml"))
ctx = create_context(headers, args, options)

ctx.options["is_function_allowed"] = (cursor, spelling) -> startswith(spelling, "cupdlpx_")

output_file = joinpath(@__DIR__, "src", "LibCuPDLPx.jl")
mkpath(dirname(output_file))

build!(ctx)

println("✅ Successfully generated LibCuPDLPx.jl at $(output_file)")
