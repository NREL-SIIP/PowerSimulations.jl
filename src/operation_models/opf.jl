struct OptimalPowerFlow <: AbstractOperationsModel end

function OptimalPowerFlow(system::PSY.PowerSystem, transmission::Type{S}; optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing, kwargs...) where {S <: PM.AbstractPowerFormulation}

    devices = Dict{String, PSI.DeviceModel}("ThermalGenerators" => PSI.DeviceModel(PSY.ThermalGen, PSI.ThermalDispatch),
                                            "RenewableGenerators" => PSI.DeviceModel(PSY.RenewableGen, PSI.RenewableConstantPowerFactor),
                                            "Loads" => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad))

    branches = Dict{String, PSI.DeviceModel}("Lines" => PSI.DeviceModel(PSY.Branch, PSI.SeriesLine))                                             
    services = Dict{String, PSI.ServiceModel}("Reserves" => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))

    return PowerOperationModel(OptimalPowerFlow ,
                                   transmission, 
                                    devices, 
                                    branches, 
                                    services,                                
                                    system,
                                    optimizer = optimizer; kwargs...)
                                
end