"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower_constraints(ps_m::CanonicalModel, devices::Array{L,1}, device_formulation::Type{InterruptiblePowerLoad}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, S <: PM.AbstractPowerFormulation}

    ts_data = [(l.name, l.maxactivepower * values(l.scalingfactor)) for l in devices]

    device_timeseries_ub(ps_m, ts_data , time_range, "load_active_ub", "Pel")

    return nothing

end


function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{L,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {L <: PSY.ElectricLoad, D <: AbstractControllablePowerLoadForm, S <: PM.AbstractPowerFormulation}

    #TODO: Filter for loads with PF = 1.0

    ps_m.constraints["load_reactive_ub"] = JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}(undef, [l.name for l in devices], time_range)

    for t in time_range, l in devices
            #Estimate PF from the load data. TODO: create a power factor field in PowerSystems
            ps_m.constraints["load_reactive_ub"][l.name, t] = JuMP.@constraint(ps_m.JuMPmodel,  ps_m.variables["Qel"][l.name, t] == ps_m.variables["Pel"][l.name, t] * sin(atan((l.maxreactivepower/l.maxactivepower))))

    end

    return nothing

end
