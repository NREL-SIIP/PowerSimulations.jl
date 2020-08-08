function get_incompatible_devices(devices_template::Dict{Symbol, DeviceModel})
    incompatible_device_types = Vector{DataType}()
    for model in values(devices_template)
        formulation = get_formulation(model)
        if formulation == FixedOutput
            if !isempty(get_services(model))
                @info "$(formulation) for $(get_device_type(model)) is not compatible with the provision of reserve services"
            end
            push!(incompatible_device_types, get_device_type(model))
        end
    end
    return incompatible_device_types
end

function construct_services!(
    psi_container::PSIContainer,
    sys::PSY.System,
    services_template::Dict{Symbol, ServiceModel},
    devices_template::Dict{Symbol, DeviceModel},
)
    isempty(services_template) && return
    incompatible_device_types = get_incompatible_devices(devices_template)
    # group service needs to be constructed last
    groupservice_key = findfirst(x -> x.formulation == GroupReserve, services_template)
    service_models = if isnothing(groupservice_key)
        collect(values(services_template))
    else
        [setdiff(
            collect(values(services_template)),
            [services_template[groupservice_key]]
        ); [services_template[groupservice_key]]]
    end
    for service_model in service_models
        @debug "Building $(service_model.service_type) with $(service_model.formulation) formulation"
        services = service_model.service_type[]
        if validate_services!(
            service_model.service_type,
            services,
            incompatible_device_types,
            sys,
        )
            construct_service!(
                psi_container,
                services,
                sys,
                service_model,
                devices_template,
                incompatible_device_types,
            )
        end
    end
    return
end

function construct_service!(
    psi_container::PSIContainer,
    services::Vector{SR},
    sys::PSY.System,
    model::ServiceModel{SR, RangeReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    services_mapping = PSY.get_contributing_device_mapping(sys)
    time_steps = model_time_steps(psi_container)
    names = [PSY.get_name(s) for s in services]

    if model_has_parameters(psi_container)
        container = add_param_container!(
            psi_container,
            UpdateRef{SR}("service_requirement", "get_requirement"),
            names,
            time_steps,
        )
        get_parameter_array(container)
    end

    add_cons_container!(
        psi_container,
        make_constraint_name(REQUIREMENT, SR),
        names,
        time_steps,
    )

    for service in services
        contributing_devices =
            services_mapping[(type = SR, name = PSY.get_name(service))].contributing_devices
        if !isempty(incompatible_device_types)
            contributing_devices =
                [d for d in contributing_devices if typeof(d) ∉ incompatible_device_types]
        end
        #Services without contributing devices should have been filtered out in the validation
        @assert !isempty(contributing_devices)
        #Variables
        add_variables!(ActiveServiceVariable, psi_container, service, contributing_devices)
        # Constraints
        service_requirement_constraint!(psi_container, service, model)
        modify_device_model!(devices_template, model, contributing_devices)

        # Cost Function
        cost_function!(psi_container, service, model)
    end
    return
end

function construct_service!(
    psi_container::PSIContainer,
    services::Vector{SR},
    sys::PSY.System,
    model::ServiceModel{SR, StepwiseCostReserve},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Vector{<:DataType},
) where {SR <: PSY.Reserve}
    services_mapping = PSY.get_contributing_device_mapping(sys)
    time_steps = model_time_steps(psi_container)
    names = [PSY.get_name(s) for s in services]
    add_variables!(ServiceRequirementVariable, psi_container, services)
    add_cons_container!(
        psi_container,
        make_constraint_name(REQUIREMENT, SR),
        names,
        time_steps,
    )

    for service in services
        contributing_devices =
            services_mapping[(
                type = typeof(service),
                name = PSY.get_name(service),
            )].contributing_devices
        if !isempty(incompatible_device_types)
            contributing_devices =
                [d for d in contributing_devices if typeof(d) ∉ incompatible_device_types]
        end
        #Variables
        add_variables!(ActiveServiceVariable, psi_container, service, contributing_devices)
        # Constraints
        service_requirement_constraint!(psi_container, service, model)
        modify_device_model!(devices_template, model, contributing_devices)

        # Cost Function
        cost_function!(psi_container, service, model.formulation)
    end
    return
end

function construct_service!(
    psi_container::PSIContainer,
    services::Vector{PSY.AGC},
    sys::PSY.System,
    ::ServiceModel{PSY.AGC, T},
    devices_template::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {T <: AbstractAGCFormulation}
    #Order is important in the addition of these variables
    for device_model in devices_template
        #TODO: make a check for the devices' models
    end
    agc_areas = [PSY.get_area(agc) for agc in services]
    areas = PSY.get_components(PSY.Area, sys)
    for area in areas
        if area ∉ agc_areas
            #    throw(IS.ConflictingInputsError("All area most have an AGC service assigned in order to model the System's Frequency regulation"))
        end
    end
    add_variables!(SteadyStateFrequencyDeviation, psi_container)
    add_variables!(AreaMismatchVariable, psi_container, areas)
    add_variables!(SmoothACE, psi_container, areas)
    add_variables!(LiftVariable, psi_container, areas)
    add_variables!(ActivePowerVariable, psi_container, areas)
    add_variables!(DeltaActivePowerUpVariable, psi_container, areas)
    add_variables!(DeltaActivePowerDownVariable, psi_container, areas)
    #add_variables!(AdditionalDeltaActivePowerUpVariable, psi_container, areas)
    #add_variables!(AdditionalDeltaActivePowerDownVariable, psi_container, areas)
    balancing_auxiliary_variables!(psi_container, sys)

    absolute_value_lift(psi_container, areas)
    frequency_response_constraint!(psi_container, sys)
    area_control_init(psi_container, services)
    smooth_ace_pid!(psi_container, services)
    aux_constraints!(psi_container, sys)
end

"""
    Constructs a service for StaticReserveGroup.
"""
function construct_service!(
    psi_container::PSIContainer,
    services::Vector{SR},
    ::PSY.System,
    model::ServiceModel{SR, GroupReserve},
    ::Dict{Symbol, DeviceModel},
    ::Vector{<:DataType},
) where {SR <: PSY.StaticReserveGroup}
    time_steps = model_time_steps(psi_container)
    names = (PSY.get_name(s) for s in services)

    if model_has_parameters(psi_container)
        container = add_param_container!(
            psi_container,
            UpdateRef{SR}("service_requirement", "get_requirement"),
            names,
            time_steps,
        )
        get_parameter_array(container)
    end

    add_cons_container!(
        psi_container,
        make_constraint_name(REQUIREMENT, SR),
        names,
        time_steps,
    )

    for service in services
        contributing_services = PSY.get_contributing_services(service)

        # check if variables exist
        check_activeservice_variables(psi_container, contributing_services)
        # Constraints
        service_requirement_constraint!(
            psi_container,
            service,
            model,
            contributing_services,
        )
    end
    return
end
