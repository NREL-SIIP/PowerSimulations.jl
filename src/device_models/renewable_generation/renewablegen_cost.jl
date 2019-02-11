function variablecost(m::JuMP.AbstractModel, devices::Array{PowerSystems.RenewableCurtailment,1}, device_formulation::Type{D}, system_formulation::Type{S}) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    p_re = m[:p_re]
    time_index = m[:p_re].axes[2]
    name_index = m[:p_re].axes[1]

    aff_expr_type = JuMP.GenericAffExpr{Float64,JuMP.variable_type(m)}
    var_cost = aff_expr_type()

    for  (ix, name) in enumerate(name_index)
        if !isa(devices[ix].econ.curtailpenalty,Nothing)
            c = gencost(m, p_re[name,:], devices[ix].econ.curtailpenalty)
        else
            continue
        end
        (isa(var_cost,aff_expr_type) && isa(c,aff_expr_type)) ? JuMP.add_to_expression!(var_cost,c) : (isa(var_cost,JuMP.GenericQuadExpr) && isa(c,JuMP.GenericQuadExpr) ? JuMP.add_to_expression!(var_cost,c) : var_cost += c)
    end

    return var_cost

end
