using PowerSimulations
using PowerSystems
#using PowerModels
#using JuMP
using Test
#using Ipopt
#using GLPK
#using OSQP

# required for reducing logging during tests
using Memento

#const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations

abstract type TestOptModel <: PSI.AbstractOperationsModel end

#ipopt_optimizer = with_optimizer(Ipopt.Optimizer, print_level = 0)
#GLPK_optimizer = with_optimizer(GLPK.Optimizer)
#OSQP_optimizer = with_optimizer(OSQP.Optimizer)

include("get_test_data.jl")

#=
@testset "Common Functionalities" begin
    include("PowerModels_interface.jl")
end

@testset "Device Constructors" begin
    include("thermal_generation_constructors.jl")
    include("renewable_generation_constructors.jl")
    include("load_constructors.jl")
    include("storage_constructors.jl")
    #include("hydro_generation_constructors.jl")
end

@testset "Network Constructors" begin
    include("network_constructors.jl")
end

@testset "Services Constructors" begin
    #include("services_constructor.jl")
end

@testset "Operation Models" begin
    include("operation_model_constructor.jl")
    include("operation_model_solve.jl")
end
=#