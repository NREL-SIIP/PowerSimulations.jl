struct UnitCommitment<:AbstractOperationModel end

function UnitCommitment(sys::PSY.System, transmission::Type{S}; optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing, kwargs...) where {S<:PM.AbstractPowerFormulation}

    devices = Dict{Symbol, DeviceModel}(:ThermalGenerators => DeviceModel(PSY.ThermalGen, ThermalStandardUnitCommitment),
                                            :RenewableGenerators => DeviceModel(PSY.RenewableGen, RenewableFullDispatch),
                                            :Loads => DeviceModel(PSY.PowerLoad, StaticPowerLoad))

branches = Dict{Symbol, DeviceModel}(:Lines => DeviceModel(PSY.Branch, SeriesLine))
services = Dict{Symbol, ServiceModel}(:Reserves => ServiceModel(PSY.Reserve, AbstractReservesFormulation))
    return OperationModel(UnitCommitment,
                                   transmission,
                                    devices,
                                    branches,
                                    services,
                                    system;
                                    optimizer = optimizer, kwargs...)
end
