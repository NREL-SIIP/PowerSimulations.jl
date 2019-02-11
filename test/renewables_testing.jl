using PowerSystems
using PowerSimulations
using JuMP

const PS = PowerSimulations

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus_uc.jl"))
include(joinpath(base_dir,"data/data_5bus_uc.jl"))


sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing, 100.0)

#Generator Active and Reactive Power Variables
@test try
    Net = PS.StandardAC
    m = Model()
    netinjection = PS.instantiate_network(Net, JuMP.variable_type(m), sys5)
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5)
true finally end

#Cooper Plate and Dispatch
@test try
    Net = PS.CopperPlatePowerModel
    m = Model();
    netinjection = PS.instantiate_network(Net, JuMP.variable_type(m), sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
true finally end

#PTDF Plate and Dispatch
@test try
    Net = PS.StandardPTDF
    m = Model();
    netinjection = PS.instantiate_network(Net, JuMP.variable_type(m), sys5);
    PS.constructdevice!(m, netinjection, RenewableGen, PS.RenewableCurtail, Net, sys5);
true finally end
