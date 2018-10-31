using PowerSystems
using PowerSimulations
using JuMP
using Clp

base_dir = string(dirname(dirname(pathof(PowerSystems))))
println(joinpath(base_dir,"data/data_5bus.jl"))
include(joinpath(base_dir,"data/data_5bus.jl"))

sys5b = PowerSystem(nodes5, generators5, loads5_DA, branches5, nothing,  100.0)

m=JuMP.Model()
devices_netinjection =  JumpAffineExpressionArray(length(sys5b.buses), sys5b.time_periods)

#Thermal Generator Models
p_th, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,   sys5b.generators.thermal, sys5b.time_periods);
m = PowerSimulations.powerconstraints(m, p_th, sys5b.generators.thermal, sys5b.time_periods)

pre_set = [d for d in sys5b.generators.renewable if !isa(d, RenewableFix)]
pre, inyection_array = PowerSimulations.activepowervariables(m, devices_netinjection,  pre_set, sys5b.time_periods)

m = PowerSimulations.powerconstraints(m, pre, pre_set, sys5b.time_periods)

test_cl = [d for d in sys5b.loads if !isa(d, PowerSystems.StaticLoad)] # Filter StaticLoads Out
pcl, inyection_array = PowerSimulations.loadvariables(m, devices_netinjection,  test_cl, sys5b.time_periods);
m = PowerSimulations.powerconstraints(m, pcl, test_cl, sys5b.time_periods)

#Injection Array
TsNets = PowerSimulations.timeseries_netinjection(sys5b)
#CopperPlate Network test
m = PowerSimulations.copperplatebalance(m, inyection_array, TsNets, sys5b.time_periods);

#Cost Components
tl = PowerSimulations.variablecost(m, pcl, test_cl);
tre = PowerSimulations.variablecost(m, pre, pre_set)
tth = PowerSimulations.variablecost(m, p_th, sys5b.generators.thermal);

#objective
@objective(m, Min, tl+tre+tth);

m = PowerSimulations.solvepsmodel(m);

true
