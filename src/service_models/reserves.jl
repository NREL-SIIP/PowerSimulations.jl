########################### Reserve constraints ######################################

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::CanonicalModel,
                           devices::Vector{T}) where {T<:PSY.ThermalGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(T)"),
                 false,
                 :reserve_balance_active;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = d -> 0 )

    return

end

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::CanonicalModel,
                           devices::Vector{H}) where {H<:PSY.HydroGen}

    return

end

"""
This function add the variables for reserves to the model
"""
function activereserve_variables!(canonical_model::CanonicalModel,
                           devices::Vector{R}) where {R<:PSY.RenewableGen}

    add_variable(canonical_model,
                 devices,
                 Symbol("R_$(T)"),
                 false,
                 :reserve_balance_active;
                 ub_value = d -> d.tech.activepowerlimits.max,
                 lb_value = 0 )

    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    reserve_device_range(canonical_model,
                 range_data,
                 Symbol("activerange_$(T)"),
                 (Symbol("P_$(T)"),
                 Symbol("R_$(T)"))
                 )
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                                     D<:AbstractThermalUnitCommitment,
                                                                     S<:PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(g), PSY.get_tech(g) |> PSY.get_activepowerlimits) for g in devices]

    reserve_device_semicontinuousrange(canonical_model,
                 range_data,
                 Symbol("activerange_$(T)"),
                 (Symbol("P_$(T)"),
                 Symbol("R_$(T)")),
                 Symbol("ON_$(T)"))
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 devices::Vector{T},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {T<:PSY.HydroGen,
                                                                     D<:AbstractThermalUnitCommitment,
                                                                     S<:PM.AbstractPowerFormulation}

    return

end

######################## output constraints without Time Series ###################################

function activereserve_constraints!(canonical_model::CanonicalModel,
                                devices::Vector{R},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                         D<:AbstractRenewableDispatchForm,
                                                         S<:PM.AbstractPowerFormulation}

    parameters = model_has_parameters(canonical_model)

    if parameters
        time_steps = model_time_steps(canonical_model)
        reserve_device_timeseries_ub(canonical_model,
                            _get_time_series(devices, time_steps),
                            Symbol("activerange_$(R)"),
                            UpdateRef{R}(Symbol("P_$(R)")),
                            Symbol("P_$(R)"),
                            Symbol("R_$(R)"))

    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_tech(d) |> PSY.get_rating)) for d in devices]
        reserve_device_range(canonical_model,
                    range_data,
                    Symbol("activerange_$(R)"),
                    Symbol("P_$(R)"),
                    Symbol("R_$(R)"))
    end

    return

end

######################### output constraints with Time Series ##############################################

function activereserve_constraints!(canonical_model::CanonicalModel,
                                 forecasts::Vector{PSY.Deterministic{R}},
                                 device_formulation::Type{D},
                                 system_formulation::Type{S}) where {R<:PSY.RenewableGen,
                                                                     D<:AbstractRenewableDispatchForm,
                                                                     S<:PM.AbstractPowerFormulation}

    if model_has_parameters(canonical_model)
        reserve_device_timeseries_param_ub(canonical_model,
                                   _get_time_series(forecasts),
                                   Symbol("activerange_$(R)"),
                                   UpdateRef{R}(Symbol("P_$(R)")),
                                   Symbol("P_$(R)"),
                                   Symbol("R_$(R)"))
    else
        reserve_device_timeseries_ub(canonical_model,
                            _get_time_series(forecasts),
                            Symbol("activerange_$(R)"),
                            Symbol("P_$(R)"),
                            Symbol("R_$(R)"))
    end

    return

end

########################### Ramp/Rate of Change constraints ################################

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                           devices::Vector{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                    D<:AbstractThermalUnitCommitment,
                                                    S<:PM.AbstractPowerFormulation}
    key = ICKey(DevicePower, T)

    if !(key in keys(canonical_model.initial_conditions))
        error("Initial Conditions for $(T) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical_model)
    resolution = model_resolution(canonical_model)
    initial_conditions = get_ini_cond(canonical_model, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        reserve_device_mixedinteger_rateofchange(canonical_model,
                                         (ramp_params, minmax_params),
                                         ini_conds,
                                         Symbol("ramp_$(T)"),
                                         (Symbol("P_$(T)"),
                                         Symbol("START_$(T)"),
                                         Symbol("STOP_$(T)"),
                                         Symbol("R_$(T)"))
                                        )
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end

function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                          devices::Vector{T},
                          device_formulation::Type{D},
                          system_formulation::Type{S}) where {T<:PSY.ThermalGen,
                                                   D<:AbstractThermalDispatchForm,
                                                   S<:PM.AbstractPowerFormulation}

    key = ICKey(DevicePower, T)

    if !(key in keys(canonical_model.initial_conditions))
        error("Initial Conditions for $(T) Rate of Change Constraints not in the model")
    end

    time_steps = model_time_steps(canonical_model)
    resolution = model_resolution(canonical_model)
    initial_conditions = get_ini_cond(canonical_model, key)
    rate_data = _get_data_for_rocc(initial_conditions, resolution)
    ini_conds, ramp_params, minmax_params = _get_data_for_rocc(initial_conditions, resolution)

    if !isempty(ini_conds)
        # Here goes the reactive power ramp limits when versions for AC and DC are added
        reseve_device_linear_rateofchange(canonical_model,
                                  ramp_params,
                                  ini_conds,
                                   Symbol("ramp_$(T)"),
                                   Symbol("P_$(T)"),
                                   Symbol("R_$(T)"))
    else
        @warn "Data doesn't contain generators with ramp limits, consider adjusting your formulation"
    end

    return

end

function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                           devices::Vector{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.HydroGen,
                                                    D<:AbstractThermalFormulation,
                                                    S<:PM.AbstractPowerFormulation}
    return

end

function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                           devices::Vector{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S}) where {T<:PSY.RenewableGen,
                                                    D<:AbstractThermalFormulation,
                                                    S<:PM.AbstractPowerFormulation}
    return

end

"""
This function adds the active power limits of generators when there are CommitmentVariables
"""
# function reserve_constraints!(canonical_model::CanonicalModel,
#                                 service::G,
#                                 device_formulation::Type{D},
#                                 service_formulation::Type{R},
#                                 system_formulation::Type{S}) where {G<:PSY.Reserve,
#                                                                     D<:AbstractThermalFormulation,
#                                                                     R<:AbstractReservesForm,
#                                                                     S<:PM.AbstractPowerFormulation}

#     requirement = service.requirement
#     devices = service.contributingdevices
#     reserve_constraint(canonical_model,
#                         requirement,
#                         Symbol("P_$(T)"),
#                         Symbol("ON_$(T)"))

#     return

# end


#=
##################
These models still need to be rewritten for the new infrastructure in PowerSimulations
##################


function reservevariables(m::JuMP.AbstractModel, devices::Array{NamedTuple{(:device, :formulation), Tuple{R, DataType}}}, time_periods::Int64) where {R<:PSY.Device}

    on_set = [d.device.name for d in devices]

    t = 1:time_periods

    p_rsv = JuMP.@variable(m, p_rsv[on_set, t] >= 0)

    return p_rsv

end


"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function activereserve_constraints!(canonical_model::CanonicalModel,
                                    service::S,
                                    formulations::Type{F}) where {S<:PSY.Service,
                                                            F<:AbstractServiceFormulation}
    
    name = Symbol("activerange")
    devices = service.contributingdevices
    expression = exp(canonical_model, name)
    if isnothing(expression)
        @error("Failed to find Constraint expression for ActiveRange Constraint")
    end
    device_range_expression!(canonical_model,
                        devices,
                        name,
                        Symbol("R_$(service.name)")
                        )

    return

end

########################### Ramp/Rate of Change constraints ################################

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function reserve_ramp_constraints!(canonical_model::CanonicalModel,
                                    service::S,
                                    formulations::Type{F}) where {S<:PSY.Service,
                                                            F<:AbstractServiceFormulation}

    name = Symbol("ramp_up")
    devices = service.contributingdevices
    expression = exp(canonical_model, name)
    if isnothing(expression)
        @error("Failed to find Constraint expression for ActiveRange Constraint")
    end
    device_rateofchange!(canonical_model,
                        devices,
                        name,
                        Symbol("R_$(service.name)"))

    return

end

############################################## Time Series ###################################

function _nodal_expression_fixed!(canonical_model::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{L}},
                                ::Type{S}) where {L<:PSY.Reserve,
                                                S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(canonical_model)

    for f in forecasts
        service = PSY.get_component(f)
        # bus_number = PSY.get_bus(d) |> PSY.get_number
        name = Symbol(service.name,"_","balance")
        expression = PSI.exp(canonical_model, name)
        if isnothing(expression)
            @error("Balance Constraint expression for $(service.name) not created")
        end
        reserve_factor = PSY.get_requirement(service)
        time_series_vector = values(PSY.get_data(f))
        for t in time_steps
            _add_to_expression!(expression,
                                1,  # TODO: needs to be actual bus numbers 
                                t,
                                -1 * time_series_vector[t] * reserve_factor)
        end
    end

    return

end


"""
This function adds the active power limits of generators when there are CommitmentVariables
"""

function service_balance(canonical_model::CanonicalModel, service::S) where {S<:PSY.Service}

    time_steps = model_time_steps(canonical_model)
    name = Symbol(service.name,"_","balance")
    expression = PSI.exp(canonical_model, name)
    canonical_model.constraints[name] = JuMPConstraintArray(undef, time_steps)
    _remove_undef!(expression)

    for t in time_steps
        canonical_model.constraints[name][t] = JuMP.@constraint(canonical_model.JuMPmodel, sum(expression.data[1:end, t]) >= 0)
    end

    return

end
