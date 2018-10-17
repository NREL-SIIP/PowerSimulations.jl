#################################################################################
# Questions
#
# - why do exported functions (e.g. ids, var, con, ref) need pacakge qualification?
# - why do non-qualified exported functions (e.g. ids, var) still throw warnings?
#
#


#################################################################################
# Model Definition

""
function build_nip_model(data::Dict{String,Any}, model_constructor; kwargs...)
    return PM.build_generic_model(data, model_constructor, post_nip; kwargs...)
end

""
function post_nip(pm::PM.GenericPowerModel)
    PM.variable_voltage(pm)
    variable_net_injection(pm)
    PM.variable_branch_flow(pm)
    PM.variable_dcline_flow(pm)

    PM.constraint_voltage(pm)

    for i in PM.ids(pm, :ref_buses)
        PM.constraint_theta_ref(pm, i)
    end

    for i in PM.ids(pm, :bus)
        constraint_kcl_ni(pm, i)
    end

    for i in PM.ids(pm, :branch)
        PM.constraint_ohms_yt_from(pm, i)
        PM.constraint_ohms_yt_to(pm, i)

        PM.constraint_voltage_angle_difference(pm, i)

        PM.constraint_thermal_limit_from(pm, i)
        PM.constraint_thermal_limit_to(pm, i)
    end

    for i in PM.ids(pm, :dcline)
        PM.constraint_dcline(pm, i)
    end
end


#################################################################################
# Model Extention Functions

"generates variables for both `active` and `reactive` net injection"
function variable_net_injection(pm::PM.GenericPowerModel; kwargs...)
    variable_active_net_injection(pm; kwargs...)
    variable_reactive_net_injection(pm; kwargs...)
end

""
function variable_active_net_injection(pm::PM.GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    PM.var(pm, nw, cnd)[:pni] = @variable(pm.model,
        [i in PM.ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_pin",
        start = 0.0
    )
end

""
function variable_reactive_net_injection(pm::PM.GenericPowerModel; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    PM.var(pm, nw, cnd)[:qni] = @variable(pm.model,
        [i in PM.ids(pm, nw, :bus)], base_name="$(nw)_$(cnd)_qin",
        start = 0.0
    )
end


""
function constraint_kcl_ni(pm::PM.GenericPowerModel, i::Int; nw::Int=pm.cnw, cnd::Int=pm.ccnd)
    if !haskey(PM.con(pm, nw, cnd), :kcl_p)
        PM.con(pm, nw, cnd)[:kcl_p] = Dict{Int,ConstraintRef}()
    end
    if !haskey(PM.con(pm, nw, cnd), :kcl_q)
        PM.con(pm, nw, cnd)[:kcl_q] = Dict{Int,ConstraintRef}()
    end

    bus = PM.ref(pm, nw, :bus, i)
    bus_arcs = PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = PM.ref(pm, nw, :bus_arcs_dc, i)

    constraint_kcl_ni(pm, nw, cnd, i, bus_arcs, bus_arcs_dc)
end


""
function constraint_kcl_ni(pm::PM.GenericPowerModel, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc)
    p = PM.var(pm, n, c, :p)
    q = PM.var(pm, n, c, :q)
    pni = PM.var(pm, n, c, :pni, i)
    qni = PM.var(pm, n, c, :qni, i)
    p_dc = PM.var(pm, n, c, :p_dc)
    q_dc = PM.var(pm, n, c, :q_dc)

    PM.con(pm, n, c, :kcl_p)[i] = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni)
    PM.con(pm, n, c, :kcl_q)[i] = @constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_dc[a_dc] for a_dc in bus_arcs_dc) == qni)
end


"active power only models ignore reactive power variables"
function variable_reactive_net_injection(pm::PM.GenericPowerModel{T}; kwargs...) where T <: PM.AbstractDCPForm
end

"active power only models ignore reactive power flows"
function constraint_kcl_ni(pm::PM.GenericPowerModel{T}, n::Int, c::Int, i::Int, bus_arcs, bus_arcs_dc) where T <: PM.AbstractDCPForm
    p = PM.var(pm, n, c, :p)
    pni = PM.var(pm, n, c, :pni, i)
    p_dc = PM.var(pm, n, c, :p_dc)

    PM.con(pm, n, c, :kcl_p)[i] = @constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_dc[a_dc] for a_dc in bus_arcs_dc) == pni)
end


