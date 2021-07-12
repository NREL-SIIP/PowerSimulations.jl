const GAEVF = JuMP.GenericAffExpr{Float64, VariableRef}
const GQEVF = JuMP.GenericQuadExpr{Float64, VariableRef}

function moi_tests(
    model::DecisionModel,
    params::Bool,
    vars::Int,
    interval::Int,
    lessthan::Int,
    greaterthan::Int,
    equalto::Int,
    binary::Bool,
)
    JuMPmodel = PSI.get_jump_model(model)
    @test (:ParameterJuMP in keys(JuMPmodel.ext)) == params
    @test JuMP.num_variables(JuMPmodel) == vars
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.Interval{Float64}) == interval
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.LessThan{Float64}) == lessthan
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.GreaterThan{Float64}) == greaterthan
    @test JuMP.num_constraints(JuMPmodel, GAEVF, MOI.EqualTo{Float64}) == equalto
    @test ((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(JuMPmodel)) ==
          binary

    return
end

function psi_constraint_test(
    model::DecisionModel,
    constraint_keys::Vector{<:PSI.ConstraintKey},
)
    constraints = PSI.get_constraints(model)
    for con in constraint_keys
        @test !isnothing(get(constraints, con, nothing))
    end
    return
end

function psi_aux_var_test(model::DecisionModel, constraint_keys::Vector{<:PSI.AuxVarKey})
    op_container = PSI.get_optimization_container(model)
    vars = PSI.get_aux_variables(op_container)
    for key in constraint_keys
        @test !isnothing(get(vars, key, nothing))
    end
    return
end

function psi_checkbinvar_test(
    model::DecisionModel,
    bin_variable_keys::Vector{<:PSI.VariableKey},
)
    container = PSI.get_optimization_container(model)
    for variable in bin_variable_keys
        for v in PSI.get_variable(container, variable)
            @test JuMP.is_binary(v)
        end
    end
    return
end

function psi_checkobjfun_test(model::DecisionModel, exp_type)
    model = PSI.get_jump_model(model)
    @test JuMP.objective_function_type(model) == exp_type
    return
end

function moi_lbvalue_test(model::DecisionModel, con_key::PSI.ConstraintKey, value::Number)
    for con in PSI.get_constraints(model)[con_key]
        @test JuMP.constraint_object(con).set.lower == value
    end
    return
end

function psi_checksolve_test(model::DecisionModel, status)
    model = PSI.get_jump_model(model)
    JuMP.optimize!(model)
    @test termination_status(model) in status
end

function psi_checksolve_test(model::DecisionModel, status, expected_result, tol = 0.0)
    res = solve!(model)
    model = PSI.get_jump_model(model)
    @test termination_status(model) in status
    obj_value = JuMP.objective_value(model)
    @test isapprox(obj_value, expected_result, atol = tol)
end

function psi_ptdf_lmps(res::ProblemResults, ptdf)
    duals = get_duals(res)
    λ = convert(
        Array,
        duals[:CopperPlateBalanceConstraint_System][
            :,
            :CopperPlateBalanceConstraint_System,
        ],
    )

    nf_duals =
        collect(keys(duals))[occursin.(string(NetworkFlowConstraint), string.(keys(duals)))]
    flow_duals =
        hcat([duals[k][:, propertynames(duals[k]) .!== :DateTime] for k in nf_duals]...)
    μ = Matrix(flow_duals[:, ptdf.axes[1]])

    buses = get_components(Bus, get_system(res))
    lmps = OrderedDict()
    for bus in buses
        lmps[get_name(bus)] = μ * ptdf[:, get_number(bus)]
    end
    lmp = λ .+ DataFrames.DataFrame(lmps)
    return lmp[!, sort(propertynames(lmp))]
end

function check_variable_unbounded(
    model::DecisionModel,
    ::Type{T},
    ::Type{U},
) where {T <: PSI.VariableType, U <: PSY.Component}
    return check_variable_unbounded(model::DecisionModel, PSI.VariableKey(T, U))
end

function check_variable_unbounded(model::DecisionModel, var_key::PSI.VariableKey)
    psi_cont = PSI.get_optimization_container(model)
    variable = PSI.get_variable(psi_cont, var_key)
    for var in variable
        if JuMP.has_lower_bound(var) || JuMP.has_upper_bound(var)
            return false
        end
    end
    return true
end

function check_variable_bounded(
    model::DecisionModel,
    ::Type{T},
    ::Type{U},
) where {T <: PSI.VariableType, U <: PSY.Component}
    return check_variable_bounded(model, PSI.VariableKey(T, U))
end

function check_variable_bounded(model::DecisionModel, var_key::PSI.VariableKey)
    psi_cont = PSI.get_optimization_container(model)
    variable = PSI.get_variable(psi_cont, var_key)
    for var in variable
        if !JuMP.has_lower_bound(var) || !JuMP.has_upper_bound(var)
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    model::DecisionModel,
    ::Type{T},
    ::Type{U},
    device_name::String,
    limit::Float64,
) where {T <: PSI.VariableType, U <: PSY.Component}
    psi_cont = PSI.get_optimization_container(model)
    variable = PSI.get_variable(psi_cont, T(), U)
    for var in variable[device_name, :]
        if !(JuMP.value(var) <= (limit + 1e-2))
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    model::DecisionModel,
    ::Type{T},
    ::Type{U},
    device_name::String,
    limit_min::Float64,
    limit_max::Float64,
) where {T <: PSI.VariableType, U <: PSY.Component}
    psi_cont = PSI.get_optimization_container(model)
    variable = PSI.get_variable(psi_cont, T(), U)
    for var in variable[device_name, :]
        if !(JuMP.value(var) <= (limit_max + 1e-2)) ||
           !(JuMP.value(var) >= (limit_min - 1e-2))
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    model::DecisionModel,
    ::Type{T},
    ::Type{U},
    ::Type{V},
    device_name::String,
    limit_min::Float64,
    limit_max::Float64,
) where {T <: PSI.VariableType, U <: PSI.VariableType, V <: PSY.Component}
    psi_cont = PSI.get_optimization_container(model)
    time_steps = PSI.get_time_steps(psi_cont)
    pvariable = PSI.get_variable(psi_cont, T(), V)
    qvariable = PSI.get_variable(psi_cont, U(), V)
    for t in time_steps
        fp = JuMP.value(pvariable[device_name, t])
        fq = JuMP.value(qvariable[device_name, t])
        flow = sqrt((fp)^2 + (fq)^2)
        if !(flow <= (limit_max + 1e-2)^2) || !(flow >= (limit_min - 1e-2)^2)
            return false
        end
    end
    return true
end

function check_flow_variable_values(
    model::DecisionModel,
    ::Type{T},
    ::Type{U},
    ::Type{V},
    device_name::String,
    limit::Float64,
) where {T <: PSI.VariableType, U <: PSI.VariableType, V <: PSY.Component}
    psi_cont = PSI.get_optimization_container(model)
    time_steps = PSI.get_time_steps(psi_cont)
    pvariable = PSI.get_variable(psi_cont, T(), V)
    qvariable = PSI.get_variable(psi_cont, U(), V)
    for t in time_steps
        fp = JuMP.value(pvariable[device_name, t])
        fq = JuMP.value(qvariable[device_name, t])
        flow = sqrt((fp)^2 + (fq)^2)
        if !(flow <= (limit + 1e-2)^2)
            return false
        end
    end
    return true
end

function PSI._jump_value(int::Int)
    @warn("This is for testing purposes only.")
    return int
end

function _test_plain_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/plain", object)
        grabbed = String(take!(io))
        @test !isnothing(grabbed)
    end
end

function _test_html_print_methods(list::Array)
    for object in list
        normal = repr(object)
        io = IOBuffer()
        show(io, "text/html", object)
        grabbed = String(take!(io))
        @test !isnothing(grabbed)
    end
end
