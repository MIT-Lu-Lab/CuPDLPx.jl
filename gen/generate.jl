using Clang.Generators
import cuPDLPx_jll
import CUDA_SDK_jll
using Printf

#############
# Paths
#############

cd(@__DIR__)

artifact_include_dir = joinpath(cuPDLPx_jll.artifact_dir, "include")
header = joinpath(artifact_include_dir, "cupdlpx.h")

# NEW: Path to the CUDA SDK headers
cuda_include_dir = joinpath(CUDA_SDK_jll.artifact_dir, "cuda", "include")

# only headers under this prefix are allowed to emit bindings
const OUR_HEADER_PREFIX = artifact_include_dir

#############
# 1. create stub headers to shadow problematic types (like half/bf16)
#    and to avoid complex math/system header inline templates.
#############

stub_dir = joinpath(@__DIR__, "clang_stub")
mkpath(stub_dir)

function ensure_stub(path::String, body::String)
    if !isfile(path)
        open(path, "w") do io
            write(io, body)
        end
    end
end

# math.h stub to avoid glibc/libm inline templates like iszero()
ensure_stub(
    joinpath(stub_dir, "math.h"),
    """
    #ifndef CUPDLPXJL_STUB_MATH_H
    #define CUPDLPXJL_STUB_MATH_H
    /* minimal math.h stub for Clang.jl binding generation */
    typedef float  __cupdlpxjl_stub_float_t;
    typedef double __cupdlpxjl_stub_double_t;
    #endif
    """
)

# ---- CUDA half / bf16 types (must be stubbed to avoid C++ template issues) ----
# We keep these stubs, but remove the unnecessary ones for driver_types.h, etc.

ensure_stub(joinpath(stub_dir, "cuda_fp16.h"), """
    struct __half_raw { unsigned short __x; };
    struct __half     { unsigned short __h; };
    """)
ensure_stub(joinpath(stub_dir, "cuda_fp16.hpp"), """
    struct __half_raw { unsigned short __x; };
    struct __half     { unsigned short __h; };
    """)

ensure_stub(joinpath(stub_dir, "cuda_bf16.h"), """
    struct __nv_bfloat16 { unsigned short __b; };
    """)
ensure_stub(joinpath(stub_dir, "cuda_bf16.hpp"), """
    struct __nv_bfloat16 { unsigned short __b; };
    """)

# Note: All other CUDA stubs (driver_types.h, cublas_v2.h, etc.) are REMOVED.
# We will use the real headers from CUDA_SDK_jll instead.


#############
# CUDA dummy macros (neutralize CUDA qualifiers/attributes)
#############

cuda_compiler_directives = [
    "-D__thread=",
    "-D__device__=",
    "-D__host__=",
    "-D__forceinline__=",
    "-D__global__=",
    "-D__shared__=",
    "-D__inline__=",
    "-D__attribute__(x)=",
    "-D__declspec(x)=",
    "-D__location__=",
    "-Dgrid_constant=",
    "-Dconstant=",
    "-Dmanaged=",
    "-D__CDPRT_DEPRECATED(x)=",
    "-D__CUDART_API_PTSZ(x)=x",
    "-D__device_builtin__=__attribute__((unused))",
]

#############
# Clang arguments
#############

# Removed the find_std_headers function, relying on get_default_args() for system
# headers and the new CUDA_SDK_jll path for CUDA headers.

args = vcat(
    get_default_args(),          # baseline args from Clang.jl
    # 1. Stub dir must come first to override problematic headers (math.h, cuda_fp16.h)
    "-I$stub_dir",
    # 2. Our JLL headers (cupdlpx.h etc.)
    "-I$artifact_include_dir",
    # 3. The actual CUDA headers (for things like driver_types.h, cublas_v2.h)
    "-I$cuda_include_dir",
    cuda_compiler_directives,    # strip CUDA attributes
    "-x", "c++",                 # parse as C++ (crucial for cuPDLPx)
    "-std=c++14",                # CUDA 12.x / modern C++ OK
)

#############
# Load generator options (.toml)
#############

options_path = joinpath(@__DIR__, "generate.toml")
opts = isfile(options_path) ? load_options(options_path) : Dict()
ctx = create_context([header], args, opts)

#############
# Filters
#############

# Only generate wrappers for functions beginning with cupdlpx_
ctx.options["is_function_allowed"] = (cursor, spelling) -> begin
    kind = Clang.getCursorKindSpelling(cursor)
    if occursin("Template", kind)
        return false
    end
    if isempty(spelling) || spelling == "operator=" || spelling == "operator"
        return false
    end
    # Only allow C API starting with cupdlpx_
    return startswith(spelling, "cupdlpx_")
end


# Don't emit nasty CUDA macros
ctx.options["is_macro_allowed"]   = (cursor, spelling, value) -> !occursin("__", spelling)

# Never emit classes / methods / constructors / destructors
ctx.options["is_class_allowed"]        = (cursor, spelling) -> false
ctx.options["is_class_method_allowed"] = _ -> false
ctx.options["is_constructor_allowed"]  = _ -> false
ctx.options["is_destructor_allowed"]   = _ -> false

# Only allow our artifact headers to contribute declarations to the binding.
ctx.options["is_file_allowed"] = (file::AbstractString) -> startswith(file, OUR_HEADER_PREFIX)

#############
# Diagnostics (optional)
#############

println("[ Info] artifact_include_dir = $artifact_include_dir")
println("[ Info] cuda_include_dir     = $cuda_include_dir")
println("[ Info] stub_dir             = $stub_dir")
println("[ Info] clang args:")
for a in args
    @printf("    %s\n", a)
end

#############
# Generate bindings
#############

mkpath(joinpath(@__DIR__, "..", "src"))
println("[ Info] Building lib bindings from $header ...")
build!(ctx)
println("[ Info] Generation complete.")

#############
# Post-process cleanup
#############

output_file = joinpath(@__DIR__, "..", "src", "LibcuPDLPx.jl")
println("[ Info] Cleaning up generated bindings at $output_file ...")

try
    data = read(output_file, String)
    original_size = length(data)

    # 1. Kill lines defining const __xxx or __xxx globals
    data = replace(data, r"^\s*(const\s+)?__\w+.*$"m => "")

    # 2. Remove stray __foo tokens that leaked
    data = replace(data, r"\b__\w+\b" => "")

    # 3. Collapse >2 blank lines
    data = replace(data, r"\n{3,}" => "\n\n")

    # 4. Remove empty dangling 'const' blocks
    data = replace(data, r"^\s*const\s*\n\s*\n"m => "\n")

    write(output_file, data)
    println("[ Info] Cleanup complete. Removed $(original_size - length(data)) bytes.")
catch e
    @warn "Cleanup failed" exception=(e, catch_backtrace())
end

cd("..")
println("[ ✅ Done] Bindings generated successfully!")
