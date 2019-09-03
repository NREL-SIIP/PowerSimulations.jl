@doc raw"""
    ps_cost(canonical_model::CanonicalModel,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::Float64,
                dt::Float64,
                sign::Float64) where {JV <: JuMP.AbstractVariableRef}

Returns linear cost terms for sum of variables with common factor to be used for cost expression for canonical model.

# Equation

``` gen_cost = sum(variable)*cost_component ```

# LaTeX

`` cost = dt\times sign\sum_{i\in I} c x_i ``

Returns:

``` sign*gen_cost*dt ```

# Arguments

* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::Float64 : cost to be associated with variable
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(canonical_model::CanonicalModel,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::Float64,
                dt::Float64,
                sign::Float64) where {JV<:JuMP.AbstractVariableRef}

    gen_cost = sum(variable)*cost_component

    return sign*gen_cost*dt

end

@doc raw"""
    ps_cost(canonical_model::CanonicalModel,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::PSY.VariableCost{Float64},
                dt::Float64,
                sign::Float64) where {JV <: JuMP.AbstractVariableRef}

Returns linear cost terms for sum of variables with common factor to be used for cost expression for canonical model.
Does this by calling ```ps_cost``` that has Float64 cost component input.

Returns:

``` ps_cost(canonical_model, variable, PSY.get_cost(cost_component), dt, sign) ```

# Arguments

* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{Float64} : container for cost to be associated with variable
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(canonical_model::CanonicalModel,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::PSY.VariableCost{Float64},
                dt::Float64,
                sign::Float64) where {JV<:JuMP.AbstractVariableRef}

    return  ps_cost(canonical_model, variable, PSY.get_cost(cost_component), dt, sign)

end

@doc raw"""
    ps_cost(canonical_model::CanonicalModel,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::PSY.VariableCost{NTuple{2, Float64}}
                dt::Float64,
                sign::Float64) where {JV <: JuMP.AbstractVariableRef}

Returns quadratic cost terms for sum of variables with common factor to be used for cost expression for canonical model.

# Equation

``` gen_cost = dt*sign*(sum(variable.^2)*cost_component[1] + sum(variable)*cost_component[2]) ```

# LaTeX

`` cost = dt\times sign (sum_{i\in I} c_1 v_i^2 + sum_{i\in I} c_2 v_i ) ``

for quadratic factor large enough. Otherwise

``` return ps_cost(canonical_model, variable, cost_component[2], dt, 1.0) ```

Returns ```gen_cost```

# Arguments

* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(canonical_model::CanonicalModel,
                 variable::JuMP.Containers.DenseAxisArray{JV},
                 cost_component::PSY.VariableCost{NTuple{2, Float64}},
                 dt::Float64,
                 sign::Float64) where {JV<:JuMP.AbstractVariableRef}

    if cost_component[1] >= eps()
        gen_cost = sum(variable.^2)*cost_component[1] + sum(variable)*cost_component[2]
        return sign*gen_cost*dt
    else
        return ps_cost(canonical_model, variable, cost_component[2], dt, 1.0)
    end

end

function _pwlparamcheck(cost_)
    flag = true;

    for i in 1:(length(cost_)-1)
        if i == 1
            (cost_[i][1]/cost_[i][2]) <= ((cost_[i+1][1] - cost_[i][1])/(cost_[i+1][2] - cost_[i][2])) ? nothing : flag = false;
        else
            ((cost_[i][1] - cost_[i-1][1])/(cost_[i][2] - cost_[i-1][2])) <= ((cost_[i+1][1] - cost_[i][1])/(cost_[i+1][2] - cost_[i][2])) ? nothing : flag = false;
        end
    end
    return flag
end

function _gen_cost(canonical_model::CanonicalModel,
                    variable::JV,
                    cost_component::Vector{NTuple{2, Float64}}) where {JV<:JuMP.AbstractVariableRef}
    
    if !_pwlparamcheck(cost_component) 
        @warn("Data provide is not suitable for linear implementation of PWL cost, Using SOS-2 implementation") ;
        gen_cost = _pwlgencost_sos(canonical_model,variable,cost_component)
    else
        gen_cost = _pwlgencost(canonical_model,variable,cost_component)
    end
    return gen_cost
end


function _pwlgencost_sos(canonical_model::CanonicalModel,
        variable::JV,
        cost_component::Vector{NTuple{2, Float64}}) where {JV<:JuMP.AbstractVariableRef}

    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(canonical_model)}()
    pwlvars = JuMP.@variable(canonical_model.JuMPmodel, [i = 1:length(cost_component)-1], 
                            base_name = "{$(variable)}_{pwl}", 
                            start = 0.0, lower_bound = 0.0, upper_bound = 1.0)

    sos2 = JuMP.@constraint(canonical_model.JuMPmodel, pwlvars in MOI.SOS2(collect(1:length(pwlvars))))

    for (ix, var) in enumerate(pwlvars)
        JuMP.add_to_expression!(gen_cost,cost_component[ix][1] * var) ;
    end

    c = JuMP.@constraint(canonical_model.JuMPmodel, variable == 
                        sum([var*cost_component[ix][2] for (ix, var) in enumerate(pwlvars) ]) );

    return gen_cost

end

function _pwlgencost(canonical_model::CanonicalModel,
        variable::JV,
        cost_component::Vector{NTuple{2, Float64}}) where {JV<:JuMP.AbstractVariableRef}

    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(canonical_model)}()
    upperbound(i) = (i == 1 ? cost_component[i][2] : (cost_component[i][2] - cost_component[i-1][2]));
    pwlvars = JuMP.@variable(canonical_model.JuMPmodel, [i = 1:length(cost_component)], base_name = "{$(variable)}_{pwl}", start = 0.0, lower_bound = 0.0, upper_bound = upperbound(i))

    for (ix, pwlvar) in enumerate(pwlvars)
        if ix == 1
            JuMP.add_to_expression!(gen_cost,cost_component[ix][1] * (pwlvar / cost_component[ix][2])) ;
        else
            JuMP.add_to_expression!(gen_cost,(cost_component[ix][1] - cost_component[ix-1][1]) *
                                            (pwlvar/(cost_component[ix][2] - cost_component[ix-1][2])));
        end
    end

    c = JuMP.@constraint(canonical_model.JuMPmodel, variable == sum([pwlvar for (ix, pwlvar) in enumerate(pwlvars) ]) )
#     JuMP.set_name(c,"{$(variable)}_{pwl}")

    return gen_cost

end

@doc raw"""
    ps_cost(canonical_model::CanonicalModel,
                 variable::JuMP.Containers.DenseAxisArray{JV},
                 cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
                 dt::Float64,
                 sign::Float64) where {JV<:JuMP.AbstractVariableRef}

Creates piecewise linear cost function using a sum of variables and expression with sign and time step included.

# Expression

```JuMP.add_to_expression!(gen_cost,c)```

Returns sign*gen_cost*dt

# LaTeX

``cost = sign\times dt \sum_{v\in V} c_v``

where ``c_v`` is given by

`` c_v = \sum_{i\in Ix} \frac{y_i - y_{i-1}}{x_i - x_{i-1}} v^{p.w.}_i ``

# Arguments

* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}}
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(canonical_model::CanonicalModel,
                 variable::JuMP.Containers.DenseAxisArray{JV},
                 cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
                 dt::Float64,
                 sign::Float64) where {JV<:JuMP.AbstractVariableRef}

    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(canonical_model)}()
    cost_array = cost_component.cost
    for var in variable
        in(true,iszero.(last.(cost_array))) ? continue : nothing ;
        c = _gen_cost(canonical_model, var, cost_array)
        JuMP.add_to_expression!(gen_cost,c)
    end

    return sign*gen_cost*dt

end

@doc raw"""
    add_to_cost(canonical_model::CanonicalModel,
                     devices::D,
                     var_name::Symbol,
                     cost_symbol::Symbol,
                     sign::Float64 = 1.0) where {D<:PSY.FlattenIteratorWrapper{<:PSY.Device}}

Adds cost expression for each device using appropriate call to ```ps_cost```.

# Expression

for d in devices

```    cost_expression = ps_cost(canonical_model,
                              variable[PSY.get_name(d), :],
                              getfield(PSY.get_op_cost(d), cost_symbol),
                              dt,
                              sign) ```
``` canonical_model.cost_function += cost_expression ```

# LaTeX

`` COST = \sum_{d\in D} cost_d ``

# Arguments

* canonical_model::CanonicalModel : the canonical model built in PowerSimulations
* devices::D : set of devices
* var_name::Symbol : name of variable
* cost_symbol::Symbol : symbol associated with costx
"""
function add_to_cost(canonical_model::CanonicalModel,
                     devices::D,
                     var_name::Symbol,
                     cost_symbol::Symbol,
                     sign::Float64 = 1.0) where {D<:PSY.FlattenIteratorWrapper{<:PSY.Device}}

    resolution = model_resolution(canonical_model)
    dt = Dates.value(Dates.Minute(resolution))/60
    variable = var(canonical_model, var_name)

    for d in devices
        cost_expression = ps_cost(canonical_model,
                                  variable[PSY.get_name(d), :],
                                  getfield(PSY.get_op_cost(d), cost_symbol),
                                  dt,
                                  sign)
        T_ce = typeof(cost_expression)
        T_cf = typeof(canonical_model.cost_function)
        if  T_cf<:JuMP.GenericAffExpr && T_ce<:JuMP.GenericQuadExpr
            canonical_model.cost_function += cost_expression
        else
            JuMP.add_to_expression!(canonical_model.cost_function, cost_expression)
        end
    end

    return

end
