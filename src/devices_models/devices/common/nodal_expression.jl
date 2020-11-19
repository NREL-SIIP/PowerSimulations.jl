struct NodalExpressionSpec
    forecast_label::String
    # TODO: Remove this hack when updating simulation execution. For now is needed
    # to store parameters from String.
    feedforward::Union{Nothing, <:AbstractAffectFeedForward}
    parameter_name::Union{String, Symbol}
    peak_value_function::Function
    multiplier::Float64
    update_ref::Type
end

"""
Construct NodalExpressionSpec for specific types.
"""
function NodalExpressionSpec(
    ::Type{T},
    ::Type{U},
    use_forecasts::Bool,
    ::Union{Nothing, <:AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    error("NodalExpressionSpec is not implemented for type $T/$U")
end

"""
Default implementation to add nodal expressions.

Users of this function must implement a method for [`NodalExpressionSpec`](@ref)
for their specific types.
Users may also implement custom nodal_expression! methods.
"""
function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
    feedforward::Union{Nothing, <:AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    nodal_expression!(psi_container, devices, PM.AbstractActivePowerModel, feedforward)
    _nodal_expression!(psi_container, devices, U, :nodal_balance_reactive, feedforward)
    return
end

function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
    feedforward::Union{Nothing, <:AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: PM.AbstractActivePowerModel}
    _nodal_expression!(psi_container, devices, U, :nodal_balance_active, feedforward)
    return
end

function _nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
    expression_name::Symbol,
    feedforward::Union{Nothing, <:AbstractAffectFeedForward},
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    # Run the Active Power Loop.
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    spec = NodalExpressionSpec(T, U, use_forecast_data, feedforward)
    if !isnothing(feedforward)
        feedforward!(
            psi_container,
            devices,
            x -> PSY.get_max_active_power(x),
            expression_name,
            feedforward,
        )
    else
        forecast_label = use_forecast_data ? spec.forecast_label : ""
        constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
        for (ix, d) in enumerate(devices)
            ts_vector = get_time_series(psi_container, d, forecast_label)
            constraint_info =
                DeviceTimeSeriesConstraintInfo(d, spec.peak_value_function, ts_vector)
            constraint_infos[ix] = constraint_info
        end
        if parameters
            @debug spec.update_ref, spec.parameter_name forecast_label
            include_parameters!(
                psi_container,
                constraint_infos,
                UpdateRef{spec.update_ref}(spec.parameter_name, forecast_label),
                expression_name,
                spec.multiplier,
            )
            return
        else
            for constraint_info in constraint_infos
                for t in model_time_steps(psi_container)
                    add_to_expression!(
                        psi_container.expressions[expression_name],
                        constraint_info.bus_number,
                        t,
                        spec.multiplier *
                        constraint_info.multiplier *
                        constraint_info.timeseries[t],
                    )
                end
            end
        end
    end
end
