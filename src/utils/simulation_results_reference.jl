struct SimulationResultsReference
    ref::Dict
    results_folder::String
    chronologies::Dict
    function SimulationResultsReference(sim::Simulation)
        date_run = convert(String, last(split(dirname(sim.internal.raw_dir), "/")))
        ref = make_references(sim, date_run)
        chronologies = Dict()
        for (stage_number, stage_name) in sim.sequence.order
            stage = get_stage(sim, stage_name)
            interval = sim.sequence.intervals[stage_name]
            resolution = PSY.get_forecasts_resolution(get_sys(stage))
            chronologies["stage-$stage_name"] = convert(Int64, (interval/resolution))
        end
        new(ref, sim.internal.results_dir, chronologies)
    end
end


"""
    make_references(sim::Simulation, date_run::String; kwargs...)

Creates a dictionary of variables with a dictionary of stages
that contains dataframes of date/step/and desired file path
so that the results can be parsed sequentially by variable
and stage type.

**Note:** make_references can only be run after run_sim_model
or else, the folder structure will not yet be populated with results

# Arguments
- `sim::Simulation = sim`: simulation object created by Simulation()
- `date_run::String = "2019-10-03T09-18-00"``: the name of the file created
that contains the specific simulation run of the date run and "-test"

# Example
```julia
sim = Simulation("test", 7, stages, "/Users/yourusername/Desktop/";
verbose = true, system_to_file = false)
execute!(sim::Simulation; verbose::Bool = false, kwargs...)
references = make_references(sim, "2019-10-03T09-18-00-test")
```

# Accepted Key Words
- `dual_constraints::Vector{Symbol}`: name of dual constraints to be added to results
"""
function make_references(sim::Simulation, date_run::String; kwargs...)
    sim.internal.date_ref[1] = sim.internal.date_range[1]
    sim.internal.date_ref[2] = sim.internal.date_range[1]
    references = Dict()
    for (stage_number, stage_name) in sim.sequence.order
        variables = Dict{Symbol, Any}()
        interval = sim.sequence.intervals[stage_name]
        variable_names = (collect(keys(sim.stages[stage_name].internal.psi_container.variables)))
        if :dual_constraints in keys(kwargs) && !isnothing(get_constraints(stage.internal.psi_container))
            dual_cons = _concat_string(kwargs[:dual_constraint])
            variable_names = vcat(variable_names, dual_cons)
        end
        for name in variable_names
            variables[name] = DataFrames.DataFrame(Date = Dates.DateTime[],
                                           Step = String[], File_Path = String[])
        end
        for s in 1:sim.steps
            stage = get_stage(sim, stage_name)
            for run in 1:stage.internal.executions
                sim.internal.current_time = sim.internal.date_ref[stage_number]
                for name in variable_names
                    full_path = joinpath(sim.internal.raw_dir, "step-$(s)-stage-$(stage_name)",
                                replace_chars("$(sim.internal.current_time)", ":", "-"), "$(name).feather")
                    if isfile(full_path)
                        date_df = DataFrames.DataFrame(Date = sim.internal.current_time,
                                                       Step = "step-$(s)", File_Path = full_path)
                        variables[name] = vcat(variables[name], date_df)
                    else
                        @info("$full_path, no such file path")
                     end
                end
                sim.internal.run_count[s][stage_number] += 1
                sim.internal.date_ref[stage_number] = sim.internal.date_ref[stage_number] + interval
            end
        end
        references["stage-$stage_name"] = variables
    end
    return references
end
"""This function outputs the step range correlated to a given date range"""
function find_step_range(rsim_result::SimulationResultsReference, stage::String, Dates::StepRange{Dates.DateTime, Any})
    references = sim_results.ref
    variable = (collect(keys(references[stage])))
    date_df = references[stage][variable[1]]
    steps = date_df[findall(in(Dates), date_df.Date), :].Step
    unique!(steps)
    return steps
end
