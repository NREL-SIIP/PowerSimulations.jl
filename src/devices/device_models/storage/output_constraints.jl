function activepower_constraints(ps_m::CanonicalModel, devices::Array{St,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {St <: PSY.Storage, D <: AbstractStorageForm, S <: PM.AbstractPowerFormulation}

    range_data_in = [(s.name, s.inputactivepowerlimits) for s in devices]

    range_data_out = [(s.name, s.outputactivepowerlimits) for s in devices]

    device_semicontinuousrange(ps_m, range_data_in, time_range, :storage_inputpower_range, :Psin, :Est)

    reserve_device_semicontinuousrange(ps_m, range_data_in, time_range, :storage_outputpower_range, :Psout, :Sst)

    return nothing

end

"""
This function adds the reactive  power limits of generators when there are CommitmentVariables
"""
function reactivepower_constraints(ps_m::CanonicalModel, devices::Array{St,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {St <: PSY.Storage, D <: AbstractStorageForm, S <: PM.AbstractPowerFormulation}

    range_data = [(s.name, s.reactivepowerlimits) for s in devices]

    device_range(ps_m, range_data , time_range, :storage_reactive_range, :Qst)

    return nothing

end
