using Test
using cuPDLPx

const Lib = cuPDLPx.LibcuPDLPx

@testset "LibcuPDLPx Translation Tests" begin

    # ==========================================
    # 1. Basic Enum Mapping Tests
    # Verify that Julia Enum values match C header definitions
    # ==========================================
    @testset "Enum Mapping" begin
        # Check termination_reason_t
        @test Int(Lib.TERMINATION_REASON_OPTIMAL) == 1
        @test Int(Lib.TERMINATION_REASON_TIME_LIMIT) == 4
        
        # Check matrix_format_t
        @test Int(Lib.matrix_dense) == 0
        @test Int(Lib.matrix_csr) == 1
        @test Int(Lib.matrix_csc) == 2
    end

    # ==========================================
    # 2. Union Memory Layout Tests (MatrixData)
    # Verify if the generated code handles memory addresses correctly.
    # The 'x + 0' logic should map the specific struct pointers to the same address as the raw data.
    # ==========================================
    @testset "Union Memory Layout (MatrixData)" begin
        # MatrixData is defined as a 32-byte blob
        @test sizeof(Lib.MatrixData) == 32

        # Simulate creating a zero-initialized Union
        data_blob = Lib.MatrixData(ntuple(_ -> UInt8(0), 32))
        data_ref = Ref(data_blob)
        data_ptr = Base.unsafe_convert(Ptr{Lib.MatrixData}, data_ref)

        # Test the .csr / .dense property accessors
        # Logic: The converted pointer address must match the original pointer address
        # because in a Union, all members start at offset 0.
        ptr_csr = data_ptr.csr
        ptr_dense = data_ptr.dense

        @test ptr_csr isa Ptr{Lib.MatrixCSR}
        @test ptr_dense isa Ptr{Lib.MatrixDense}
        
        # Critical Check: Verify memory addresses are identical
        @test Int(data_ptr) == Int(ptr_csr)
        @test Int(data_ptr) == Int(ptr_dense)
        
        println("   > MatrixData Union logic verified (Address offsets are correct).")
    end

    # ==========================================
    # 3. Real C Function Call Test (Core Verification)
    # ==========================================
    @testset "C Function Call: set_default_parameters" begin
        # 1. Allocate memory on the Julia side
        # Create an uninitialized pdhg_parameters_t struct on the heap
        params_ref = Ref{Lib.pdhg_parameters_t}()
        
        # Get the raw pointer
        params_ptr = Base.unsafe_convert(Ptr{Lib.pdhg_parameters_t}, params_ref)

        # 2. Call the C function
        # This function writes default values into the memory pointed to by params_ptr.
        Lib.set_default_parameters(params_ptr)
        
        # 3. Read and verify results
        # Retrieve the modified struct from the Ref
        params = params_ref[]

        # Verify sanity of the loaded values.
        # If alignment/padding is wrong, these will likely be garbage values.
        
        # verbose is usually a boolean (0 or 1)
        # @test (params.verbose == true) || (params.verbose == false)
        @test params.verbose isa Integer
        
        # Time limit should be positive (usually infinity or a large number)
        @test params.termination_criteria.time_sec_limit > 0
        
        # Check nested struct alignment
        # eps_optimal_relative should be a small positive number (e.g., 1e-6)
        @test params.termination_criteria.eps_optimal_relative < 1.0
        @test params.termination_criteria.eps_optimal_relative >= 0.0

        # Check restart parameters
        @test params.restart_params.k_p isa Float64

        println("   > Successfully called set_default_parameters from C library.")
        println("   > Defaults loaded check: Time Limit = $(params.termination_criteria.time_sec_limit)")
    end

    # ==========================================
    # 4. Struct Size Sanity Check
    # Ensure Julia's matrix_desc_t matches the C definition padding
    # ==========================================
    @testset "Struct Size Sanity Check" begin
        # matrix_desc_t is defined as NTuple{56, UInt8} in the generated code
        @test sizeof(Lib.matrix_desc_t) == 56
    end

    # ==========================================
    # 6. Integration Test: Read MPS from file
    # ==========================================
    @testset "MPS File Solve (AFIRO)" begin
        # 1. Create a temporary MPS file
        # AFIRO is a standard small Netlib LP test case (27 rows, 32 cols)
        mps_content = """
            NAME          AFIRO
            ROWS
            E  R09
            E  R10
            L  X05
            L  X21
            E  R12
            E  R13
            L  X17
            L  X18
            L  X19
            L  X20
            E  R19
            E  R20
            L  X27
            L  X44
            E  R22
            E  R23
            L  X40
            L  X41
            L  X42
            L  X43
            L  X45
            L  X46
            L  X47
            L  X48
            L  X49
            L  X50
            L  X51
            N  COST
            COLUMNS
                X01       X48               .301   R09                -1.
                X01       R10              -1.06   X05                 1.
                X02       X21                -1.   R09                 1.
                X02       COST               -.4
                X03       X46                -1.   R09                 1.
                X04       X50                 1.   R10                 1.
                X06       X49               .301   R12                -1.
                X06       R13              -1.06   X17                 1.
                X07       X49               .313   R12                -1.
                X07       R13              -1.06   X18                 1.
                X08       X49               .313   R12                -1.
                X08       R13               -.96   X19                 1.
                X09       X49               .326   R12                -1.
                X09       R13               -.86   X20                 1.
                X10       X45              2.364   X17                -1.
                X11       X45              2.386   X18                -1.
                X12       X45              2.408   X19                -1.
                X13       X45              2.429   X20                -1.
                X14       X21                1.4   R12                 1.
                X14       COST              -.32
                X15       X47                -1.   R12                 1.
                X16       X51                 1.   R13                 1.
                X22       X46               .109   R19                -1.
                X22       R20               -.43   X27                 1.
                X23       X44                -1.   R19                 1.
                X23       COST               -.6
                X24       X48                -1.   R19                 1.
                X25       X45                -1.   R19                 1.
                X26       X50                 1.   R20                 1.
                X28       X47               .109   R22               -.43
                X28       R23                 1.   X40                 1.
                X29       X47               .108   R22               -.43
                X29       R23                 1.   X41                 1.
                X30       X47               .108   R22               -.39
                X30       R23                 1.   X42                 1.
                X31       X47               .107   R22               -.37
                X31       R23                 1.   X43                 1.
                X32       X45              2.191   X40                -1.
                X33       X45              2.219   X41                -1.
                X34       X45              2.249   X42                -1.
                X35       X45              2.279   X43                -1.
                X36       X44                1.4   R23                -1.
                X36       COST              -.48
                X37       X49                -1.   R23                 1.
                X38       X51                 1.   R22                 1.
                X39       R23                 1.   COST               10.
            RHS
                B         X50               310.   X51               300.
                B         X05                80.   X17                80.
                B         X27               500.   R23                44.
                B         X40               500.
            ENDATA
        """
        mps_path = joinpath(tempdir(), "afiro.mps")
        write(mps_path, mps_content)
        println("   > Created temp MPS file at: $mps_path")

        # 2. Read MPS using the C library
        # Note: read_mps_file returns a Ptr{lp_problem_t}
        prob = Lib.read_mps_file(mps_path)
        
        @test prob != C_NULL
        
        # Verify problem dimensions (AFIRO should be small)
        prob_data = unsafe_load(prob)
        println("   > Loaded Problem: $(prob_data.num_variables) vars, $(prob_data.num_constraints) cons")
        # AFIRO stats: 32 variables, 27 constraints (values depend on presolve/parsing, but checking >0 is good)
        @test prob_data.num_variables > 0
        @test prob_data.num_constraints > 0

        # 3. Solve
        params_ref = Ref{Lib.pdhg_parameters_t}()
        Lib.set_default_parameters(Base.unsafe_convert(Ptr{Lib.pdhg_parameters_t}, params_ref))
        params_ptr = Base.unsafe_convert(Ptr{Lib.pdhg_parameters_t}, params_ref)
        
        result_ptr = Lib.solve_lp_problem(prob, params_ptr)
        @test result_ptr != C_NULL
        
        result = unsafe_load(result_ptr)
        println("   > MPS Solve Status: $(result.termination_reason)")
        println("   > MPS Primal Obj: $(result.primal_objective_value)")

        # AFIRO optimal objective is approx -4.6475314286e+02
        target_obj = -464.75
        @test isapprox(result.primal_objective_value, target_obj, rtol=1e-2)

        # 4. Cleanup
        Lib.cupdlpx_result_free(result_ptr)
        Lib.lp_problem_free(prob)
        rm(mps_path) # delete temp file
    end

    # ==========================================
    # 7. Integration Test: Direct Matrix Construction
    # ==========================================
    @testset "Direct API Solve" begin
        println("\n   > Starting Direct API Solve Test...")

        # -------------------------------------------------------
        # Problem Data Definition
        #  maximize
        #        x +   y + 2 z
        #  subject to
        #        x + 2 y + 3 z <= 4
        #        x +   y       >= 1
        #        0 <= x, y, z <= 1
        # -------------------------------------------------------
        n_vars = 3
        m_cons = 2

        # 1. Objective Vector (Minimize direction)
        c = Cdouble[-1.0, -1.0, -2.0]
        obj_const = Cdouble[0.0] # Must be a pointer

        # 2. Variable Bounds (Relax Binary -> [0, 1])
        var_lb = Cdouble[0.0, 0.0, 0.0]
        var_ub = Cdouble[1.0, 1.0, 1.0]

        # 3. Constraint Matrix Data (CSR Format)
        # Row 0:  1.0,  2.0, 3.0  (indices 0, 1, 2)
        # Row 1: -1.0, -1.0       (indices 0, 1)
        csr_vals    = Cdouble[1.0, 2.0, 3.0, -1.0, -1.0]
        csr_col_ind = Cint[0, 1, 2, 0, 1]
        csr_row_ptr = Cint[0, 3, 5]
        nnz = Cint(5)

        # 4. Constraint Bounds
        # Row 0: ... <= 4.0  -> (-Inf, 4.0]
        # Row 1: ... <= -1.0 -> (-Inf, -1.0]
        con_lb = Cdouble[-Inf, -Inf]
        con_ub = Cdouble[4.0, -1.0]

        # -------------------------------------------------------
        # C Struct Construction
        # -------------------------------------------------------
        
        # A. Construct MatrixCSR
        A_csr = Lib.MatrixCSR(
            nnz,
            pointer(csr_row_ptr),
            pointer(csr_col_ind),
            pointer(csr_vals)
        )

        # B. Construct matrix_desc_t        
        # 1. Allocate zeroed struct on Julia side
        A_desc_ref = Ref{Lib.matrix_desc_t}()
        A_desc_ref[] = Lib.matrix_desc_t(ntuple(_ -> UInt8(0), 56)) # Clear memory
        A_desc_ptr = Base.unsafe_convert(Ptr{Lib.matrix_desc_t}, A_desc_ref)

        # 2. Set Scalar Fields
        A_desc_ptr.m = Cint(m_cons)
        A_desc_ptr.n = Cint(n_vars)
        A_desc_ptr.fmt = Lib.matrix_csr
        A_desc_ptr.zero_tolerance = 1e-12

        # 3. Set The Union Data
        A_desc_ptr.data.csr = A_csr

        # -------------------------------------------------------
        # Create and Solve
        # -------------------------------------------------------
        
        # Create LP Problem
        prob = Lib.create_lp_problem(
            pointer(c),
            A_desc_ptr,
            pointer(con_lb),
            pointer(con_ub),
            pointer(var_lb),
            pointer(var_ub),
            pointer(obj_const)
        )
        @test prob != C_NULL

        # Setup Parameters
        params_ref = Ref{Lib.pdhg_parameters_t}()
        params_ptr = Base.unsafe_convert(Ptr{Lib.pdhg_parameters_t}, params_ref)
        Lib.set_default_parameters(params_ptr)

        # Solve
        result_ptr = Lib.solve_lp_problem(prob, params_ptr)
        @test result_ptr != C_NULL
        
        result = unsafe_load(result_ptr)

        # -------------------------------------------------------
        # Validation
        # -------------------------------------------------------
        println("   > Direct Solve Status: $(result.termination_reason)")
        println("   > Direct Solve Obj: $(result.primal_objective_value)")

        # Optimal happens at x=1, y=0, z=1 => Obj = 3.
        # Since we minimized negative: Target = -3.0
        @test result.termination_reason == Lib.TERMINATION_REASON_OPTIMAL
        @test isapprox(result.primal_objective_value, -3.0, atol=1e-4)

        # Cleanup
        Lib.cupdlpx_result_free(result_ptr)
        Lib.lp_problem_free(prob)
        println("   > Direct API Solve test passed.")
    end

end

include("MOI_wrapper.jl")
