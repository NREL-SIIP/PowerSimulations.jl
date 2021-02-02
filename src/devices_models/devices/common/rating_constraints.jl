@doc raw"""
Constructs constraint from rating data and related variable tuple.

# Constraint

``` var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2 ```

where r in rating data and t in time steps.

# LaTeX

`` x_1^2 + x_2^2 \leq r^2 ``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* rating_data::Vector{Tuple{String, Float64}} : rating data name (1) and value (2)
* cons_name::Symbol : name of the constraint
* var_names::Tuple{Symbol, Symbol} : the names of the variables
- : var_names[1] : var1
- : var_names[2] : var2
"""
function rating_constraint!(
    optimization_container::OptimizationContainer,
    rating_data::Vector{Tuple{String, Float64}},
    cons_name::Symbol,
    var_names::Tuple{Symbol, Symbol},
)
    time_steps = model_time_steps(optimization_container)
    var1 = get_variable(optimization_container, var_names[1])
    var2 = get_variable(optimization_container, var_names[2])
    add_cons_container!(
        optimization_container,
        cons_name,
        (r[1] for r in rating_data),
        time_steps,
    )
    constraint = get_constraint(optimization_container, cons_name)

    for r in rating_data
        for t in time_steps
            constraint[r[1], t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                var1[r[1], t]^2 + var2[r[1], t]^2 <= r[2]^2
            )
        end
    end

    return
end
