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
    branch_rate_bounds!(optimization_container, devices, model, S)
    return
end

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
