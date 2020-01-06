function include_parameters(psi_container::PSIContainer,
                            data::Array,
                            param_reference::UpdateRef,
                            axs...)
    if !model_has_parameters(psi_container)
        throw(IS.DataFormatError("Operational Model doesn't have parameters enabled. Include the keyword use_parameters=true"))
    end
    param = add_param_container!(psi_container, param_reference, axs...)
    Cidx = CartesianIndices(length.(axs))
    for idx in Cidx
        param.data[idx] = PJ.add_parameter(psi_container.JuMPmodel, data[idx])
    end
    return param
end

function include_parameters(psi_container::PSIContainer,
                            ts_data::Vector{DeviceTimeSeries},
                            param_reference::UpdateRef,
                            expression_name::Symbol,
                            multiplier::Float64 = 1.0)
    if !model_has_parameters(psi_container)
        throw(IS.DataFormatError("Operational Model doesn't have parameters enabled. Include the keyword use_parameters=true"))
    end
    time_steps = model_time_steps(psi_container)
    param = add_param_container!(psi_container, param_reference, (r.name for r in ts_data), time_steps)
    expr = get_expression(psi_container, expression_name)
    for t in time_steps, r in ts_data
        param[r.name, t] = PJ.add_parameter(psi_container.JuMPmodel, r.timeseries[t]);
        _add_to_expression!(expr, r.bus_number, t, param[r.name, t], r.multiplier * multiplier)
    end
    return param
end
