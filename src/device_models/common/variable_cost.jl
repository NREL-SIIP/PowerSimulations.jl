function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Function)

    store = Array{JuMP.AbstractJuMPScalar,1}(undef,length(variable.axes[1]))

    for (ix, element) in enumerate(variable)
        store[ix] = cost_component(element)
    end

    gen_cost = sum(store)

    return gen_cost

end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Float64)

    gen_cost = sum(variable)*cost_component

    return gen_cost

end

function pwlgencost(m::JuMP.Model, variable::VariableRef, cost_component::Array{Tuple{Float64, Float64}})

    pwlvars = @variable(m, [i = 1:(length(cost_component)-1)], base_name = "pwl_{$(variable)}")

    for (ix, pwlvar) in enumerate(pwlvars)
        c = @constraint(m, pwlvar <= cost_component[ix + 1][2])
        c = @constraint(m, pwlvar >= 0)
    end
    c = @constraint(m, variable == sum(pwlvars[ix] for (ix, pwlvar) in enumerate(pwlvars)))

    # TODO: Check for performance this syntax, the changes in GenericAffExpr might require refactoring

    gen_cost = AffExpr()

    for (ix, pwlvar) in enumerate(pwlvars)

        gen_cost = JuMP.add_to_expression!(gen_cost, (cost_component[ix + 1][1] * cost_component[ix + 1][2] - cost_component[ix][1] * cost_component[ix][2]) / (cost_component[ix + 1][2] - cost_component[ix][2])  * pwlvar)

    end

    return gen_cost
end

function gencost(m::JuMP.Model, variable::JuMPArray{JuMP.VariableRef}, cost_component::Array{Tuple{Float64, Float64}})

    gen_cost = JuMP.AffExpr()

    for var in variable
        c = pwlgencost(m, var, cost_component)
        JuMP.add_to_expression!(gen_cost,c)
    end

    return gen_cost

end
