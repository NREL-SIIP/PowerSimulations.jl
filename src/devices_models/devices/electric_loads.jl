abstract type AbstractLoadFormulation <: AbstractDeviceFormulation end
abstract type AbstractControllablePowerLoadFormulation <: AbstractLoadFormulation end
struct StaticPowerLoad <: AbstractLoadFormulation end
struct InterruptiblePowerLoad <: AbstractControllablePowerLoadFormulation end
struct DispatchablePowerLoad <: AbstractControllablePowerLoadFormulation end

########################### dispatchable load variables ####################################
function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: ActivePowerVariable, U <: PSY.ElectricLoad}
    return AddVariableSpec(;
        variable_name = make_variable_name(T, U),
        binary = false,
        expression_name = :nodal_balance_active,
        sign = -1.0,
        lb_value_func = x -> 0.0,
        ub_value_func = x -> PSY.get_max_active_power(x),
    )
end

function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: ReactivePowerVariable, U <: PSY.ElectricLoad}
    return AddVariableSpec(;
        variable_name = make_variable_name(T, U),
        binary = false,
        expression_name = :nodal_balance_reactive,
        sign = -1.0,
        lb_value_func = x -> 0.0,
        ub_value_func = x -> PSY.get_max_reactive_power(x),
    )
end

function AddVariableSpec(
    ::Type{T},
    ::Type{U},
    ::PSIContainer,
) where {T <: OnVariable, U <: PSY.ElectricLoad}
    return AddVariableSpec(; variable_name = make_variable_name(T, U), binary = true)
end

####################################### Reactive Power Constraints #########################
"""
Reactive Power Constraints on Controllable Loads Assume Constant power_factor
"""
function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ReactivePowerVariable},
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:AbstractControllablePowerLoadFormulation},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
)
    return DeviceRangeConstraintSpec(;
        custom_psi_container_func = custom_reactive_power_constraints!,
    )
end

function custom_reactive_power_constraints!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{<:AbstractControllablePowerLoadFormulation},
) where {T <: PSY.ElectricLoad}
    time_steps = model_time_steps(psi_container)
    constraint = JuMPConstraintArray(undef, [PSY.get_name(d) for d in devices], time_steps)
    assign_constraint!(psi_container, REACTIVE, T, constraint)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        pf = sin(atan((PSY.get_max_reactive_power(d) / PSY.get_max_active_power(d))))
        reactive = get_variable(psi_container, REACTIVE_POWER, T)[name, t]
        real = get_variable(psi_container, ACTIVE_POWER, T)[name, t] * pf
        constraint[name, t] = JuMP.@constraint(psi_container.JuMPmodel, reactive == real)
    end
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:DispatchablePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad}
    if (!use_parameters && !use_forecasts)
        return DeviceRangeConstraintSpec(;
            range_constraint_spec = RangeConstraintSpec(;
                constraint_name = make_constraint_name(
                    RangeConstraint,
                    ActivePowerVariable,
                    T,
                ),
                variable_name = make_variable_name(ActivePowerVariable, T),
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_range!,
                constraint_struct = DeviceRangeConstraintInfo,
            ),
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            parameter_name = use_parameters ? ACTIVE_POWER : nothing,
            forecast_label = "max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_param_ub! :
                              device_timeseries_ub!,
        ),
    )
end

function DeviceRangeConstraintSpec(
    ::Type{<:RangeConstraint},
    ::Type{ActivePowerVariable},
    ::Type{T},
    ::Type{<:InterruptiblePowerLoad},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
    use_parameters::Bool,
    use_forecasts::Bool,
) where {T <: PSY.ElectricLoad}
    if (!use_parameters && !use_forecasts)
        return DeviceRangeConstraintSpec(;
            range_constraint_spec = RangeConstraintSpec(;
                constraint_name = make_constraint_name(
                    RangeConstraint,
                    ActivePowerVariable,
                    T,
                ),
                variable_name = make_variable_name(ActivePowerVariable, T),
                bin_variable_names = [make_variable_name(OnVariable, T)],
                limits_func = x -> (min = 0.0, max = PSY.get_active_power(x)),
                constraint_func = device_semicontinuousrange!,
                constraint_struct = DeviceRangeConstraintInfo,
            ),
        )
    end

    return DeviceRangeConstraintSpec(;
        timeseries_range_constraint_spec = TimeSeriesConstraintSpec(
            constraint_name = make_constraint_name(RangeConstraint, ActivePowerVariable, T),
            variable_name = make_variable_name(ActivePowerVariable, T),
            bin_variable_name = make_variable_name(OnVariable, T),
            parameter_name = use_parameters ? ON : nothing,
            forecast_label = "max_active_power",
            multiplier_func = x -> PSY.get_max_active_power(x),
            constraint_func = use_parameters ? device_timeseries_ub_bigM! :
                              device_timeseries_ub_bin!,
        ),
    )
end

########################## Addition to the nodal balances ##################################

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractPowerModel},
    use_forecasts::Bool,
    feedforward::Union{Nothing, <:AbstractAffectFeedForward},
) where {T <: PSY.ElectricLoad}
    return NodalExpressionSpec(
        "max_active_power",
        feedforward,
        REACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_reactive_power(x) : x -> PSY.get_reactive_power(x),
        -1.0,
        T,
    )
end

function NodalExpressionSpec(
    ::Type{T},
    ::Type{<:PM.AbstractActivePowerModel},
    use_forecasts::Bool,
    feedforward::Union{Nothing, <:AbstractAffectFeedForward},
) where {T <: PSY.ElectricLoad}
    return NodalExpressionSpec(
        "max_active_power",
        feedforward,
        ACTIVE_POWER,
        use_forecasts ? x -> PSY.get_max_active_power(x) : x -> PSY.get_active_power(x),
        -1.0,
        T,
    )
end

############################## FormulationControllable Load Cost ###########################
function AddCostSpec(
    ::Type{T},
    ::Type{DispatchablePowerLoad},
    ::PSIContainer,
) where {T <: PSY.ControllableLoad}
    cost_function = x -> isnothing(x) ? 1.0 : PSY.get_variable(x)
    return AddCostSpec(;
        variable_type = ActivePowerVariable,
        component_type = T,
        variable_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end

function AddCostSpec(
    ::Type{T},
    ::Type{InterruptiblePowerLoad},
    ::PSIContainer,
) where {T <: PSY.ControllableLoad}
    cost_function = x -> isnothing(x) ? 1.0 : PSY.get_fixed(x)
    return AddCostSpec(;
        variable_type = OnVariable,
        component_type = T,
        fixed_cost = cost_function,
        multiplier = OBJECTIVE_FUNCTION_NEGATIVE,
    )
end
