function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{L},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.System,
                           time_range::UnitRange{Int64};
                           kwargs...) where {L <: PSY.ControllableLoad,
                                             D <: AbstractControllablePowerLoadForm,
                                             S <: PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = collect(PSY.get_components(device, sys))
    
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    activepower_variables(ps_m, devices, time_range);

    reactivepower_variables(ps_m, devices, time_range);

    #Constraints
    if forecast 
        forecasts = [forecast for forecast in  sys.forecasts[:DA] if isa(forecast,PSY.Deterministic{device})]
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation, time_range, parameters)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)
    end

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                           device::Type{L},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.System,
                           time_range::UnitRange{Int64};
                           kwargs...) where {L <: PSY.ControllableLoad,
                                             D <: AbstractControllablePowerLoadForm,
                                             S <: PM.AbstractActivePowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = collect(PSY.get_components(device, sys))
   
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)                                             

    #Variables
    activepower_variables(ps_m, devices, time_range)

    #Constraints
    if forecast 
        forecasts = [forecast for forecast in  sys.forecasts[:DA] if isa(forecast,PSY.Deterministic{device})]
        activepower_constraints(ps_m, forecasts, device_formulation, system_formulation, time_range, parameters)
    else
        activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)
    end

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{L},
                                        device_formulation::Type{StaticPowerLoad},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        time_range::UnitRange{Int64};
                                        kwargs...) where {L <: PSY.ElectricLoad,
                                                          S <: PM.AbstractPowerFormulation}

    forecast = get(kwargs, :forecast, true)

    devices = collect(PSY.get_components(device, sys))
    
    if validate_available_devices(devices, device)
        return
    end

    parameters = get(kwargs, :parameters, true)

    if forecast 
        forecasts = [forecast for forecast in  sys.forecasts[:DA] if isa(forecast,PSY.Deterministic{device})]
        nodal_expression(ps_m, forecasts, system_formulation, time_range, parameters)
    else
        nodal_expression(ps_m, devices, system_formulation, time_range, parameters)
    end   

    return

end

function _internal_device_constructor!(ps_m::CanonicalModel,
                                        device::Type{L},
                                        device_formulation::Type{D},
                                        system_formulation::Type{S},
                                        sys::PSY.System,
                                        time_range::UnitRange{Int64};
                                        kwargs...) where {L <: PSY.StaticLoad,
                                                          D <: AbstractControllablePowerLoadForm,
                                                          S <: PM.AbstractPowerFormulation}

    if device_formulation != StaticPowerLoad
        @warn("The Formulation $(D) only applies to Controllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad")                                              
    end

    _internal_device_constructor!(ps_m, 
                                  device,
                                  StaticPowerLoad,
                                  system_formulation,
                                  sys,
                                  time_range; 
                                  kwargs...)

end    
