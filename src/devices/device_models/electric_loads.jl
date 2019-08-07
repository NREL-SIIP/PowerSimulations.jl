abstract type AbstractLoadFormulation<:AbstractDeviceFormulation end

abstract type AbstractControllablePowerLoadForm<:AbstractLoadFormulation end

struct StaticPowerLoad<:AbstractLoadFormulation end

struct InterruptiblePowerLoad<:AbstractControllablePowerLoadForm end

struct DispatchablePowerLoad<:AbstractControllablePowerLoadForm end

########################### dispatchable load variables ############################################

function activepower_variables(ps_m::CanonicalModel,
                               devices::PSY.FlattenIteratorWrapper{L}) where {L<:PSY.ElectricLoad}
    add_variable(ps_m,
                 devices,
                 Symbol("P_$(L)"),
                 false,
                 :nodal_balance_active, -1.0;
                 lb = x -> 0.0)

    return

end


function reactivepower_variables(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{L}) where {L<:PSY.ElectricLoad}
    add_variable(ps_m,
                 devices,
                 Symbol("Q_$(L)"),
                 false,
                 :nodal_balance_reactive, -1.0)

    return

end

function commitment_variables(ps_m::CanonicalModel,
                              devices::PSY.FlattenIteratorWrapper{L}) where {L<:PSY.ElectricLoad}

    add_variable(ps_m,
                 devices,
                 Symbol("ON_$(L)"),
                 true)

    return

end

####################################### Reactive Power Constraints ######################################
"""
Reactive Power Constraints on Loads Assume Constant PowerFactor
"""
function reactivepower_constraints(ps_m::CanonicalModel,
                                   devices::PSY.FlattenIteratorWrapper{L},
                                   device_formulation::Type{D},
                                   system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                       D<:AbstractControllablePowerLoadForm,
                                                                       S<:PM.AbstractPowerFormulation}
    time_steps = model_time_steps(ps_m)
    key = Symbol("reactive_$(L)")
    ps_m.constraints[key] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_maxreactivepower(d)/PSY.get_maxactivepower(d))))
        ps_m.constraints[key][PSY.get_name(d), t] = JuMP.@constraint(ps_m.JuMPmodel,
                        ps_m.variables[Symbol("Q_$(L)")][name, t] == ps_m.variables[Symbol("P_$(L)")][name, t]*pf)
    end

    return

end


######################## output constraints without Time Series ###################################
function _get_time_series(devices::PSY.FlattenIteratorWrapper{T},
                          time_steps::UnitRange{Int64}) where {T<:PSY.ElectricLoad}

    names = Vector{String}(undef, length(devices))
    series = Vector{Vector{Float64}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        names[ix] = PSY.get_name(d)
        series[ix] = fill(PSY.get_maxactivepower(d), (time_steps[end]))
    end

    return names, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{L},
                                 device_formulation::Type{DispatchablePowerLoad},
                                 system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                     S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    if model_has_parameters(ps_m)
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices, time_steps),
                                   Symbol("active_$(L)"),
                                   RefParam{L}(Symbol("P_$(L)")),
                                   Symbol("P_$(L)"))
    else
        range_data = [(PSY.get_name(d), (min = 0.0, max = PSY.get_maxactivepower(d))) for d in devices]
        device_range(ps_m,
                    range_data,
                    Symbol("activerange_$(L)"),
                    Symbol("P_$(L)")
                    )
    end

    return

end

"""
This function works only if the the Param_L <= PSY.get_maxactivepower(g)
"""
function activepower_constraints(ps_m::CanonicalModel,
                                 devices::PSY.FlattenIteratorWrapper{L},
                                 device_formulation::Type{InterruptiblePowerLoad},
                                 system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                          S<:PM.AbstractPowerFormulation}
    time_steps = model_time_steps(ps_m)

    if model_has_parameters(ps_m)
        device_timeseries_ub_bigM(ps_m,
                                 _get_time_series(devices, time_steps),
                                 Symbol("active_$(L)"),
                                 Symbol("P_$(L)"),
                                 RefParam{L}(Symbol("P_$(L)")),
                                 Symbol("ON_$(L)"))
    else
        device_timeseries_ub_bin(ps_m,
                                _get_time_series(devices, time_steps),
                                Symbol("active_$(L)"),
                                Symbol("P_$(L)"),
                                Symbol("ON_$(L)"))
    end

    return

end

######################### output constraints with Time Series ##############################################

function _get_time_series(forecasts::Vector{PSY.Deterministic{L}}) where {L<:PSY.ElectricLoad}

    names = Vector{String}(undef, length(forecasts))
    ratings = Vector{Float64}(undef, length(forecasts))
    series = Vector{Vector{Float64}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        component = PSY.get_component(f)
        names[ix] = PSY.get_name(component)
        series[ix] = values(PSY.get_data(f))
        ratings[ix] = PSY.get_maxactivepower(component)
    end

    return names, ratings, series

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{PSY.Deterministic{L}},
                                 device_formulation::Type{DispatchablePowerLoad},
                                 system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                     S<:PM.AbstractPowerFormulation}

    if model_has_parameters(ps_m)
        device_timeseries_param_ub(ps_m,
                                   _get_time_series(devices),
                                   Symbol("active_$(L)"),
                                   RefParam{L}(Symbol("P_$(L)")),
                                   Symbol("P_$(L)"))
    else
        device_timeseries_ub(ps_m,
                            _get_time_series(devices),
                            Symbol("active_$(L)"),
                            Symbol("P_$(L)"))
    end

    return

end

function activepower_constraints(ps_m::CanonicalModel,
                                 devices::Vector{PSY.Deterministic{L}},
                                 device_formulation::Type{InterruptiblePowerLoad},
                                 system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                     S<:PM.AbstractPowerFormulation}

    if model_has_parameters(ps_m)
        device_timeseries_ub_bigM(ps_m,
                                 _get_time_series(devices),
                                 Symbol("active_$(L)"),
                                 Symbol("P_$(L)"),
                                 RefParam{L}(Symbol("P_$(L)")),
                                 Symbol("ON_$(L)"))
    else
        device_timeseries_ub_bin(ps_m,
                                _get_time_series(devices),
                                Symbol("active_$(L)"),
                                Symbol("P_$(L)"),
                                Symbol("ON_$(L)"))
    end

    return

end


############################ injection expression with parameters ####################################

########################################### Devices ####################################################

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_bus(d) |> PSY.get_number
        name = PSY.get_name(d)
        active_power = PSY.get_maxactivepower(d)
        reactive_power = PSY.get_maxreactivepower(d)
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector, -1.0)
        ts_data_reactive[ix] = (name, bus_number, reactive_power, time_series_vector, -1.0)
    end

    include_parameters(ps_m,
                  ts_data_active,
                  RefParam{L}(Symbol("P_$(L)")),
                  :nodal_balance_active)
    include_parameters(ps_m,
                   ts_data_reactive,
                   RefParam{L}(Symbol("Q_$(L)")),
                   :nodal_balance_reactive)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        bus_number = PSY.get_bus(d) |> PSY.get_number
        name = PSY.get_name(d)
        active_power = PSY.get_maxactivepower(d)
        time_series_vector = ones(time_steps[end])
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector, -1.0)
    end

    include_parameters(ps_m,
                  ts_data_active,
                  RefParam{L}(Symbol("P_$(L)")),
                  :nodal_balance_active)

    return

end

############################################## Time Series ###################################
function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))
    ts_data_reactive = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        name = PSY.get_name(device)
        active_power = PSY.get_maxactivepower(device)
        reactive_power = PSY.get_maxreactivepower(device)
        time_series_vector = values(PSY.get_data(f))
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector)
        ts_data_reactive[ix] = (name, bus_number, reactive_power, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    RefParam{L}(Symbol("P_$(L)")),
                    :nodal_balance_active,
                    -1.0)
    include_parameters(ps_m,
                    ts_data_reactive,
                    RefParam{L}(Symbol("Q_$(L)")),
                    :nodal_balance_reactive,
                    -1.0)

    return

end

function _nodal_expression_param(ps_m::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)
    ts_data_active = Vector{Tuple{String, Int64, Float64, Vector{Float64}}}(undef, length(forecasts))

    for (ix, f) in enumerate(forecasts)
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        name = PSY.get_name(device)
        active_power = PSY.get_maxactivepower(device)
        time_series_vector = values(PSY.get_data(f))
        ts_data_active[ix] = (name, bus_number, active_power, time_series_vector)
    end

    include_parameters(ps_m,
                    ts_data_active,
                    RefParam{L}(Symbol("P_$(L)")),
                    :nodal_balance_active,
                    -1.0)

    return

end

############################ injection expression with fixed values ####################################

########################################### Devices ####################################################

function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        bus_number = PSY.get_bus(d) |> PSY.get_number
        active_power = PSY.get_maxactivepower(d)
        reactive_power = PSY.get_maxreactivepower(d)
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            -1*active_power);
        _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                            bus_number,
                            t,
                            -1*reactive_power);
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{L},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for t in time_steps, d in devices
        bus_number = PSY.get_bus(d) |> PSY.get_number
        active_power = PSY.get_maxactivepower(d)
        _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                            bus_number,
                            t,
                            -1*active_power);
    end

    return

end

############################################## Time Series ###################################

function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractPowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        active_power = PSY.get_maxactivepower(device)
        reactive_power = PSY.get_maxreactivepower(device)
        time_series_vector = values(PSY.get_data(f))
        for t in time_steps
            bus_number = PSY.get_bus(device) |> PSY.get_number
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                -1 * time_series_vector[t] * active_power)
            _add_to_expression!(ps_m.expressions[:nodal_balance_reactive],
                                bus_number,
                                t,
                                -1 * time_series_vector[t] * reactive_power)
        end
    end

    return

end


function _nodal_expression_fixed(ps_m::CanonicalModel,
                                forecasts::Vector{PSY.Deterministic{L}},
                                system_formulation::Type{S}) where {L<:PSY.ElectricLoad,
                                                                    S<:PM.AbstractActivePowerFormulation}

    time_steps = model_time_steps(ps_m)

    for f in forecasts
        device = PSY.get_component(f)
        bus_number = PSY.get_bus(device) |> PSY.get_number
        active_power = PSY.get_maxactivepower(device)
        time_series_vector = values(PSY.get_data(f))
        for t in time_steps
            bus_number = PSY.get_bus(device) |> PSY.get_number
            _add_to_expression!(ps_m.expressions[:nodal_balance_active],
                                bus_number,
                                t,
                                -1 * time_series_vector[t] * active_power)
        end
    end

    return

end

##################################### Controllable Load Cost ######################################

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{L},
                       device_formulation::Type{DispatchablePowerLoad},
                       system_formulation::Type{S}) where {L<:PSY.ControllableLoad,
                                                           S<:PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("P_$(L)"),
                :variable,
                -1.0)

    return

end

function cost_function(ps_m::CanonicalModel,
                       devices::PSY.FlattenIteratorWrapper{L},
                       device_formulation::Type{InterruptiblePowerLoad},
                       system_formulation::Type{S}) where {L<:PSY.ControllableLoad,
                                                           S<:PM.AbstractPowerFormulation}

    add_to_cost(ps_m,
                devices,
                Symbol("ON_$(L)"),
                :fixed,
                -1.0)

    return

end
