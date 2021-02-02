construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{<:PSY.ACBranch, <:AbstractBranchFormulation},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{<:PSY.DCBranch, <:AbstractDCLineFormulation},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

# This method might be redundant but added for completness of the formulations
construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::DeviceModel{<:PSY.Branch, <:UnboundedBranches},
    ::Type{<:PM.AbstractPowerModel},
) = nothing

construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{<:PSY.ACBranch, <:UnboundedBranches},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{<:PSY.ACBranch, <:UnboundedBranches},
    ::Type{<:PM.AbstractActivePowerModel},
) = nothing

# For DC Power only. Implements Bounds only and constraints
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, Br},
    ::Type{S},
) where {
    B <: PSY.ACBranch,
    Br <: AbstractBoundedBranchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    !(get_feedforward(model) === nothing) && throw(
        IS.ConflictingInputsError(
            "$(Br) formulation doesn't support FeedForward. Use Constrained Branch Formulation instead",
        ),
    )
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

# For DC Power only. Implements Constraints only
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractBranchFormulation},
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

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractBranchFormulation},
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
    model::DeviceModel{B, Br},
    ::Type{S},
) where {B <: PSY.DCBranch, Br <: AbstractDCLineFormulation, S <: PM.AbstractPowerModel}
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
