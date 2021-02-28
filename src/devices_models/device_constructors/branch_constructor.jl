# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranch},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchBounds},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.DCBranch, <:AbstractDCLineFormulation},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Type{<:PM.AbstractPowerModel},
) = nothing

# For DC Power only. Implements constraints
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

# For DC Power only
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)

    if !validate_available_devices(B, devices)
        return
    end
    add_variables!(optimization_container, StandardPTDFModel(), devices)

    # PTDF flow calculations
    ptdf = get_PTDF(optimization_container)
    buses = PSY.get_components(PSY.Bus, sys)

    time_steps = model_time_steps(optimization_container)
    constraint_val = JuMPConstraintArray(undef, time_steps)
    network_flow =
        add_cons_container!(optimization_container, :network_flow, ptdf.axes[1], time_steps)

    flow_variables = get_variable(optimization_container, FLOW_ACTIVE_POWER, B)
    nodal_balance_expressions =
        get_expression(optimization_container, :nodal_balance_active)
    jump_model = get_jump_model(optimization_container)
    for t in time_steps, br in devices
        br_name = get_name(br)
        network_flow[br_name, t] = JuMP.@constraint(
            jump_model,
            flow_variables[br_name, t] -
            sum(ptdf[br_name, i] * nodal_balance_expressions[i, t] for i in ptdf.axes[2])
            == 0.0
        )
    end

    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_bounds!(optimization_container, devices, model, S)
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchBounds},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_bounds!(optimization_container, devices, model, S)
    return
end

# DC Branches
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{S},
) where {B <: PSY.DCBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{S},
) where {B <: PSY.DCBranch, S <: Union{StandardPTDFModel, PTDFPowerModel}}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, StandardPTDFModel(), devices)
    flow_variables = get_variable(optimization_container, FLOW_ACTIVE_POWER, B)
    time_steps = model_time_steps(optimization_container)

    for t in time_steps, d in devices
        br_name = PSY.get_name(d)
        add_to_expression!(
            optimization_container.expressions[:nodal_balance_active],
            flow_variables[br_name, t],
            -1.0,
            (PSY.get_number(PSY.get_arc(d).from), t)...,
        )
        add_to_expression!(
            optimization_container.expressions[:nodal_balance_active],
            flow_variables[br_name, t],
            1.0,
            (PSY.get_number(PSY.get_arc(d).to), t)...,
        )
    end
@show optimization_container.expressions[:nodal_balance_active]
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

#=
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    devices = get_available_components(PSY.MonitoredLine, sys)
    if !validate_available_devices(PSY.MonitoredLine, devices)
        return
    end
    branch_flow_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.MonitoredLine, FlowMonitoredLine},
    ::Type{S},
) where {S <: PM.AbstractPowerModel}
    devices = get_available_components(PSY.MonitoredLine, sys)
    if !validate_available_devices(PSY.MonitoredLine, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    branch_flow_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end
=#
