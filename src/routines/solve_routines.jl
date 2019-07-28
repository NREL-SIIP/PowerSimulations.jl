""" Solves Operational Models"""
function solve_op_model!(op_model::OperationModel; kwargs...)

    timed_log = Dict{Symbol, Any}()

    if op_model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER

        if !(:optimizer in keys(kwargs))

            error("No Optimizer has been defined, can't solve the operational problem")

        else
            _, timed_log[:timed_solve_time],
            timed_log[:solve_bytes_alloc],
            timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical_model.JuMPmodel,
                                                          kwargs[:optimizer])

        end

    else

        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] = @timed JuMP.optimize!(op_model.canonical_model.JuMPmodel)

    end

    vars_result = get_model_result(op_model)
    optimizer_log = get_optimizer_log(op_model)
    obj_value = Dict(:OBJECTIVE_FUNCTION => JuMP.objective_value(op_model.canonical_model.JuMPmodel))
    merge!(optimizer_log, timed_log)

    return OpertationModelResults(vars_result, obj_value, optimizer_log)

end


function _run_stage(stage::Stage, results_path::String)

    for run in stage.execution_count
        if stage.model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
            error("No Optimizer has been defined, can't solve the operational problem")
        end

        timed_log = Dict{Symbol, Any}()
        _, timed_log[:timed_solve_time],
        timed_log[:solve_bytes_alloc],
        timed_log[:sec_in_gc] =  @timed JuMP.optimize!(stage.model.canonical_model.JuMPmodel)

        write_model_result(stage.model, results_path)
        write_optimizer_log(timed_log, stage.model, results_path)

    end

    return

end


"""Runs Simulations"""
function run_sim_model!(sim::Simulation; verbose::Bool = false)

    if sim.ref.reset
        sim.ref.reset = false
    elseif sim.ref.reset == false
        error("Reset the simulation")
    end

    steps = get_steps(sim)
    for s in 1:steps
        verbose && println("Step $(s)")
        for (ix, stage) in enumerate(sim.stages)
            verbose && println("Stage $(ix)")
            interval = PSY.get_forecasts_interval(stage.model.sys)
            for run in 1:stage.execution_count
                sim.ref.current_time = sim.ref.date_ref[ix]
                verbose && println("Simulation TimeStamp: $(sim.ref.current_time)")
                raw_results_path = joinpath(sim.ref.raw,"step-$(s)-stage-$(ix)","$(sim.ref.current_time)")
                mkpath(raw_results_path)
                _run_stage(stage, raw_results_path)
                sim.ref.run_count[s][ix] += 1
                sim.ref.date_ref[ix] = sim.ref.date_ref[ix] + interval
            end
        end
    end

    return

end
