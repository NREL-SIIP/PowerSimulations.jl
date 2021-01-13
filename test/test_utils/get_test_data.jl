const BASE_DIR = string(dirname(dirname(pathof(PowerSimulations))))
const DATA_DIR = joinpath(BASE_DIR, "test/test_data")
include(joinpath(DATA_DIR, "data_5bus_pu.jl"))
include(joinpath(DATA_DIR, "data_14bus_pu.jl"))

# Test Systems

# The code below provides a mechanism to optimally construct test systems. The first time a
# test builds a particular system name, the code will construct the system from raw files
# and then serialize it to storage.
# When future tests ask for the same system the code will deserialize it from storage.
#
# If you add a new system then you need to add an entry to TEST_SYSTEMS.
# The build function should accept `kwargs...` instead of specific named keyword arguments.
# This will allow easy addition of new parameters in the future.

struct TestSystemLabel
    name::String
    add_forecasts::Bool
    add_reserves::Bool
end

mutable struct SystemBuildStats
    count::Int
    initial_construct_time::Float64
    serialize_time::Float64
    min_deserialize_time::Float64
    max_deserialize_time::Float64
    total_deserialize_time::Float64
end

function SystemBuildStats(initial_construct_time::Float64, serialize_time::Float64)
    return SystemBuildStats(1, initial_construct_time, serialize_time, 0.0, 0.0, 0.0)
end

function update_stats!(stats::SystemBuildStats, deserialize_time::Float64)
    stats.count += 1
    if stats.min_deserialize_time == 0 || deserialize_time < stats.min_deserialize_time
        stats.min_deserialize_time = deserialize_time
    end
    if deserialize_time > stats.max_deserialize_time
        stats.max_deserialize_time = deserialize_time
    end
    stats.total_deserialize_time += deserialize_time
end

avg_deserialize_time(stats::SystemBuildStats) = stats.total_deserialize_time / stats.count

g_system_serialized_files = Dict{TestSystemLabel, String}()
g_system_build_stats = Dict{TestSystemLabel, SystemBuildStats}()

function initialize_system_serialized_files()
    empty!(g_system_serialized_files)
    empty!(g_system_build_stats)
end

function summarize_system_build_stats()
    @info "System Build Stats"
    labels = sort!(collect(keys(g_system_build_stats)), by = x -> x.name)
    for label in labels
        x = g_system_build_stats[label]
        system = "$(label.name) add_forecasts=$(label.add_forecasts) add_reserves=$(label.add_reserves)"
        @info system x.count x.initial_construct_time x.serialize_time x.min_deserialize_time x.max_deserialize_time avg_deserialize_time(
            x,
        )
    end
end

function build_system(name::String; add_forecasts = true, add_reserves = false)
    !haskey(TEST_SYSTEMS, name) && error("invalid system name: $name")
    label = TestSystemLabel(name, add_forecasts, add_reserves)
    sys_params = TEST_SYSTEMS[name]
    if !haskey(g_system_serialized_files, label)
        @debug "Build new system" label sys_params.description
        build_func = sys_params.build
        start = time()
        sys = build_func(;
            add_forecasts = add_forecasts,
            add_reserves = add_reserves,
            time_series_in_memory = sys_params.time_series_in_memory,
        )
        construct_time = time() - start
        serialized_file = joinpath(mktempdir(), "sys.json")
        start = time()
        PSY.to_json(sys, serialized_file)
        serialize_time = time() - start
        g_system_build_stats[label] = SystemBuildStats(construct_time, serialize_time)
        g_system_serialized_files[label] = serialized_file
    else
        @debug "Deserialize system from file" label
        start = time()
        sys = System(
            g_system_serialized_files[label];
            time_series_in_memory = sys_params.time_series_in_memory,
        )
        update_stats!(g_system_build_stats[label], time() - start)
    end

    return sys
end

function build_c_sys5(; kwargs...)
    nodes = nodes5()
    c_sys5 =
        System(100.0, nodes, thermal_generators5(nodes), loads5(nodes), branches5(nodes))

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5, l, Deterministic("max_active_power", forecast_data))
        end
    end

    return c_sys5
end

function build_c_sys5_ml(; kwargs...)
    nodes = nodes5()
    c_sys5_ml = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_ml))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_ml, l, Deterministic("max_active_power", forecast_data))
        end
    end

    return c_sys5_ml
end

function build_c_sys14(; kwargs...)
    nodes = nodes14()
    c_sys14 = System(
        100.0,
        nodes,
        thermal_generators14(nodes),
        loads14(nodes),
        branches14(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        forecast_data = SortedDict{Dates.DateTime, TimeArray}()
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys14))
            ini_time = timestamp(timeseries_DA14[ix])[1]
            forecast_data[ini_time] = timeseries_DA14[ix]
            add_time_series!(c_sys14, l, Deterministic("max_active_power", forecast_data))
        end
    end

    return c_sys14
end

function build_c_sys5_re(; kwargs...)
    nodes = nodes5()
    c_sys5_re = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_re))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_re, l, Deterministic("max_active_power", forecast_data))
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_re))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_re, r, Deterministic("max_active_power", forecast_data))
        end
    end

    if get(kwargs, :add_reserves, false)
        reserve_re = reserve5_re(get_components(RenewableDispatch, c_sys5_re))
        add_service!(c_sys5_re, reserve_re[1], get_components(RenewableDispatch, c_sys5_re))
        add_service!(
            c_sys5_re,
            reserve_re[2],
            [collect(get_components(RenewableDispatch, c_sys5_re))[end]],
        )
        # ORDC
        add_service!(c_sys5_re, reserve_re[3], get_components(RenewableDispatch, c_sys5_re))
        for (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_re))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_re, serv, Deterministic("requirement", forecast_data))
        end
        for (ix, serv) in enumerate(get_components(ReserveDemandCurve, c_sys5_re))
            forecast_data = SortedDict{Dates.DateTime, Vector{IS.PWL}}()
            for t in 1:2
                ini_time = timestamp(ORDC_cost_ts[t])[1]
                forecast_data[ini_time] = TimeSeries.values(ORDC_cost_ts[t])
            end
            resolution = timestamp(ORDC_cost_ts[1])[2] - timestamp(ORDC_cost_ts[1])[1]
            set_variable_cost!(
                c_sys5_re,
                serv,
                Deterministic("variable_cost", forecast_data, resolution),
            )
        end
    end

    return c_sys5_re
end

function build_c_sys5_re_only(; kwargs...)
    nodes = nodes5()
    c_sys5_re_only = System(
        100.0,
        nodes,
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_re_only))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_re_only,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_re_only))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_re_only,
                r,
                Deterministic("max_active_power", forecast_data),
            )
        end
    end

    return c_sys5_re_only
end

function build_c_sys5_hy(; kwargs...)
    nodes = nodes5()
    c_sys5_hy = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        [hydro_generators5(nodes)[1]],
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hy))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_hy, l, Deterministic("max_active_power", forecast_data))
        end
        for (ix, r) in enumerate(get_components(HydroGen, c_sys5_hy))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_hy, r, Deterministic("max_active_power", forecast_data))
        end
    end

    return c_sys5_hy
end

function build_c_sys5_hyd(; kwargs...)
    nodes = nodes5()
    c_sys5_hyd = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        [hydro_generators5(nodes)[2]],
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hyd,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, h) in enumerate(get_components(HydroGen, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hyd,
                h,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_hyd, h, Deterministic("hydro_budget", forecast_data))
        end
        for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hyd))
            forecast_data_inflow = SortedDict{Dates.DateTime, TimeArray}()
            forecast_data_target = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data_inflow[ini_time] = hydro_timeseries_DA[t][ix] .* 0.8
                forecast_data_target[ini_time] = hydro_timeseries_DA[t][ix] .* 0.5
            end
            add_time_series!(c_sys5_hyd, h, Deterministic("inflow", forecast_data_inflow))
            add_time_series!(
                c_sys5_hyd,
                h,
                Deterministic("storage_target", forecast_data_target),
            )
        end
    end

    if get(kwargs, :add_reserves, false)
        reserve_hy = reserve5_hy(get_components(HydroEnergyReservoir, c_sys5_hyd))
        add_service!(
            c_sys5_hyd,
            reserve_hy[1],
            get_components(HydroEnergyReservoir, c_sys5_hyd),
        )
        add_service!(
            c_sys5_hyd,
            reserve_hy[2],
            [collect(get_components(HydroEnergyReservoir, c_sys5_hyd))[end]],
        )
        # ORDC curve
        add_service!(
            c_sys5_hyd,
            reserve_hy[3],
            get_components(HydroEnergyReservoir, c_sys5_hyd),
        )
        for (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_hyd, serv, Deterministic("requirement", forecast_data))
        end
        for (ix, serv) in enumerate(get_components(ReserveDemandCurve, c_sys5_hyd))
            forecast_data = SortedDict{Dates.DateTime, Vector{IS.PWL}}()
            for t in 1:2
                ini_time = timestamp(ORDC_cost_ts[t])[1]
                forecast_data[ini_time] = TimeSeries.values(ORDC_cost_ts[t])
            end
            resolution = timestamp(ORDC_cost_ts[1])[2] - timestamp(ORDC_cost_ts[1])[1]
            set_variable_cost!(
                c_sys5_hyd,
                serv,
                Deterministic("variable_cost", forecast_data, resolution),
            )
        end
    end

    return c_sys5_hyd
end

function build_c_sys5_bat(; kwargs...)
    time_series_in_memory = get(kwargs, :time_series_in_memory, true)
    nodes = nodes5()
    c_sys5_bat = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes),
        battery5(nodes);
        time_series_in_memory = time_series_in_memory,
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_bat,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_bat,
                r,
                Deterministic("max_active_power", forecast_data),
            )
        end
    end

    if get(kwargs, :add_reserves, false)
        reserve_bat = reserve5_re(get_components(RenewableDispatch, c_sys5_bat))
        add_service!(c_sys5_bat, reserve_bat[1], get_components(GenericBattery, c_sys5_bat))
        add_service!(c_sys5_bat, reserve_bat[2], get_components(GenericBattery, c_sys5_bat))
        # ORDC
        add_service!(c_sys5_bat, reserve_bat[3], get_components(GenericBattery, c_sys5_bat))
        for (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_bat, serv, Deterministic("requirement", forecast_data))
        end
        for (ix, serv) in enumerate(get_components(ReserveDemandCurve, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, Vector{IS.PWL}}()
            for t in 1:2
                ini_time = timestamp(ORDC_cost_ts[t])[1]
                forecast_data[ini_time] = TimeSeries.values(ORDC_cost_ts[t])
            end
            resolution = timestamp(ORDC_cost_ts[1])[2] - timestamp(ORDC_cost_ts[1])[1]
            set_variable_cost!(
                c_sys5_bat,
                serv,
                Deterministic("variable_cost", forecast_data, resolution),
            )
        end
    end

    return c_sys5_bat
end

function build_c_sys5_bat_ems(; kwargs...)
    time_series_in_memory = get(kwargs, :time_series_in_memory, true)
    nodes = nodes5()
    c_sys5_bat = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes),
        batteryems5(nodes);
        time_series_in_memory = time_series_in_memory,
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_bat,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_bat,
                r,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, r) in enumerate(get_components(BatteryEMS, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(battery_target_timeseries_DA[t])[1]
                forecast_data[ini_time] = battery_target_timeseries_DA[t]
            end
            add_time_series!(
                c_sys5_bat,
                r,
                Deterministic("storage_target", forecast_data),
            )
        end
    end

    if get(kwargs, :add_reserves, false)
        reserve_bat = reserve5_re(get_components(RenewableDispatch, c_sys5_bat))
        add_service!(c_sys5_bat, reserve_bat[1], get_components(BatteryEMS, c_sys5_bat))
        add_service!(c_sys5_bat, reserve_bat[2], get_components(BatteryEMS, c_sys5_bat))
        # ORDC
        add_service!(c_sys5_bat, reserve_bat[3], get_components(BatteryEMS, c_sys5_bat))
        for (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_bat, serv, Deterministic("requirement", forecast_data))
        end
        for (ix, serv) in enumerate(get_components(ReserveDemandCurve, c_sys5_bat))
            forecast_data = SortedDict{Dates.DateTime, Vector{IS.PWL}}()
            for t in 1:2
                ini_time = timestamp(ORDC_cost_ts[t])[1]
                forecast_data[ini_time] = TimeSeries.values(ORDC_cost_ts[t])
            end
            resolution = timestamp(ORDC_cost_ts[1])[2] - timestamp(ORDC_cost_ts[1])[1]
            set_variable_cost!(
                c_sys5_bat,
                serv,
                Deterministic("variable_cost", forecast_data, resolution),
            )
        end
    end

    return c_sys5_bat
end


function build_c_sys5_il(; kwargs...)
    nodes = nodes5()
    c_sys5_il = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_il))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_il, l, Deterministic("max_active_power", forecast_data))
        end
        for (ix, i) in enumerate(get_components(InterruptibleLoad, c_sys5_il))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Iload_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = Iload_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_il, i, Deterministic("max_active_power", forecast_data))
        end
    end

    if get(kwargs, :add_reserves, false)
        reserve_il = reserve5_il(get_components(InterruptibleLoad, c_sys5_il))
        add_service!(c_sys5_il, reserve_il[1], get_components(InterruptibleLoad, c_sys5_il))
        add_service!(
            c_sys5_il,
            reserve_il[2],
            [collect(get_components(InterruptibleLoad, c_sys5_il))[end]],
        )
        # ORDC
        add_service!(c_sys5_il, reserve_il[3], get_components(InterruptibleLoad, c_sys5_il))
        for (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_il))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[ix])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_il, serv, Deterministic("requirement", forecast_data))
        end
        for (ix, serv) in enumerate(get_components(ReserveDemandCurve, c_sys5_il))
            forecast_data = SortedDict{Dates.DateTime, Vector{IS.PWL}}()
            for t in 1:2
                ini_time = timestamp(ORDC_cost_ts[t])[1]
                forecast_data[ini_time] = TimeSeries.values(ORDC_cost_ts[t])
            end
            resolution = timestamp(ORDC_cost_ts[1])[2] - timestamp(ORDC_cost_ts[1])[1]
            set_variable_cost!(
                c_sys5_il,
                serv,
                Deterministic("variable_cost", forecast_data, resolution),
            )
        end
    end

    return c_sys5_il
end

function build_c_sys5_dc(; kwargs...)
    nodes = nodes5()
    c_sys5_dc = System(
        100.0,
        nodes,
        thermal_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5_dc(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_dc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_dc, l, Deterministic("max_active_power", forecast_data))
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_dc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_dc, r, Deterministic("max_active_power", forecast_data))
        end
    end

    return c_sys5_dc
end

function build_c_sys14_dc(; kwargs...)
    nodes = nodes14()
    c_sys14_dc = System(
        100.0,
        nodes,
        thermal_generators14(nodes),
        loads14(nodes),
        branches14_dc(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        forecast_data = SortedDict{Dates.DateTime, TimeArray}()
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys14_dc))
            ini_time = timestamp(timeseries_DA14[ix])[1]
            forecast_data[ini_time] = timeseries_DA14[ix]
            add_time_series!(
                c_sys14_dc,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
    end

    return c_sys14_dc
end

function build_c_sys5_reg(; kwargs...)
    nodes = nodes5()

    c_sys5_reg =
        System(100.0, nodes, thermal_generators5(nodes), loads5(nodes), branches5(nodes))

    area = Area("1")
    add_component!(c_sys5_reg, area)
    [set_area!(b, area) for b in get_components(Bus, c_sys5_reg)]
    AGC_service = PSY.AGC(
        name = "AGC_Area1",
        available = true,
        bias = 739.0,
        K_p = 2.5,
        K_i = 0.1,
        K_d = 0.0,
        delta_t = 4,
        area = first(get_components(Area, c_sys5_reg)),
    )
    #add_component!(c_sys5_reg, AGC_service)
    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_reg))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_reg,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (_, l) in enumerate(get_components(ThermalStandard, c_sys5_reg))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][1])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][1]
            end
            add_time_series!(
                c_sys5_reg,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
    end

    contributing_devices = Vector()
    for g in get_components(Generator, c_sys5_reg)
        droop =
            isa(g, ThermalStandard) ? 0.04 * get_base_power(g) : 0.05 * get_base_power(g)
        p_factor = (up = 1.0, dn = 1.0)
        t = RegulationDevice(g, participation_factor = p_factor, droop = droop)
        add_component!(c_sys5_reg, t)
        push!(contributing_devices, t)
    end
    add_service!(c_sys5_reg, AGC_service, contributing_devices)
    return c_sys5_reg
end

# System to test UC Forms
#Park City and Sundance Have non-binding Ramp Limitst at an Hourly Resolution
# Solitude, Sundance and Brighton have binding time_up constraints.
# Solitude and Brighton have binding time_dn constraints.
# Sundance has non-binding Time Down constraint at an Hourly Resolution
# Alta, Park City and Brighton start at 0.

thermal_generators5_uc_testing(nodes) = [
    ThermalStandard(
        name = "Alta",
        available = true,
        status = false,
        bus = nodes[1],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 0.5,
        prime_mover = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.2, max = 0.40),
        reactive_power_limits = (min = -0.30, max = 0.30),
        ramp_limits = nothing,
        time_limits = nothing,
        operation_cost = ThreePartCost((0.0, 14.0), 0.0, 4.0, 2.0),
        base_power = 100.0,
    ),
    ThermalStandard(
        name = "Park City",
        available = true,
        status = false,
        bus = nodes[1],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 2.2125,
        prime_mover = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.65, max = 1.70),
        reactive_power_limits = (min = -1.275, max = 1.275),
        ramp_limits = (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        time_limits = nothing,
        operation_cost = ThreePartCost((0.0, 15.0), 0.0, 1.5, 0.75),
        base_power = 100.0,
    ),
    ThermalStandard(
        name = "Solitude",
        available = true,
        status = true,
        bus = nodes[3],
        active_power = 2.7,
        reactive_power = 0.00,
        rating = 5.20,
        prime_mover = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 1.0, max = 5.20),
        reactive_power_limits = (min = -3.90, max = 3.90),
        ramp_limits = (up = 0.0012 * 5.2, down = 0.0012 * 5.2),
        time_limits = (up = 5.0, down = 3.0),
        operation_cost = ThreePartCost((0.0, 30.0), 0.0, 3.0, 1.5),
        base_power = 100.0,
    ),
    ThermalStandard(
        name = "Sundance",
        available = true,
        status = false,
        bus = nodes[4],
        active_power = 0.0,
        reactive_power = 0.00,
        rating = 2.5,
        prime_mover = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 1.0, max = 2.0),
        reactive_power_limits = (min = -1.5, max = 1.5),
        ramp_limits = (up = 0.015 * 2.5, down = 0.015 * 2.5),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = ThreePartCost((0.0, 40.0), 0.0, 4.0, 2.0),
        base_power = 100.0,
    ),
    ThermalStandard(
        name = "Brighton",
        available = true,
        status = true,
        bus = nodes[5],
        active_power = 6.0,
        reactive_power = 0.0,
        rating = 7.5,
        prime_mover = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 3.0, max = 6.0),
        reactive_power_limits = (min = -4.50, max = 4.50),
        ramp_limits = (up = 0.0015 * 7.5, down = 0.0015 * 7.5),
        time_limits = (up = 5.0, down = 3.0),
        operation_cost = ThreePartCost((0.0, 10.0), 0.0, 1.5, 0.75),
        base_power = 100.0,
    ),
];

function build_sys_ramp_testing(; kwargs...)
    node = Bus(1, "nodeA", "REF", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 100.0, 1.0, 2.0)
    gen_ramp = [
        ThermalStandard(
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            active_power = 0.20, # Active power
            reactive_power = 0.010,
            rating = 0.5,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.0, max = 0.40),
            reactive_power_limits = nothing,
            ramp_limits = nothing,
            time_limits = nothing,
            operation_cost = ThreePartCost((0.0, 14.0), 0.0, 4.0, 2.0),
            base_power = 100.0,
        ),
        ThermalStandard(
            name = "Park City",
            available = true,
            status = true,
            bus = node,
            active_power = 0.70, # Active Power
            reactive_power = 0.20,
            rating = 2.0,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.7, max = 2.20),
            reactive_power_limits = nothing,
            ramp_limits = (up = 0.010625 * 2.0, down = 0.010625 * 2.0),
            time_limits = nothing,
            operation_cost = ThreePartCost((0.0, 15.0), 0.0, 1.5, 0.75),
            base_power = 100.0,
        ),
    ]
    DA_ramp = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  4:00:00",
            "d/m/y  H:M:S",
        ),
    )
    ramp_load = [0.9, 1.1, 2.485, 2.175, 0.9]
    ts_dict = SortedDict(DA_ramp[1] => ramp_load)
    load_forecast_ramp = Deterministic("max_active_power", ts_dict, Hour(1))
    ramp_test_sys = System(100.0)
    add_component!(ramp_test_sys, node)
    add_component!(ramp_test_sys, load)
    add_component!(ramp_test_sys, gen_ramp[1])
    add_component!(ramp_test_sys, gen_ramp[2])
    add_time_series!(ramp_test_sys, load, load_forecast_ramp)
    return ramp_test_sys
end

function build_c_sys5_uc(; kwargs...)
    nodes = nodes5()
    c_sys5_uc = System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_uc, l, Deterministic("max_active_power", forecast_data))
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_uc, r, Deterministic("max_active_power", forecast_data))
        end
        for (ix, i) in enumerate(get_components(InterruptibleLoad, c_sys5_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Iload_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = Iload_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_uc, r, Deterministic("max_active_power", forecast_data))
        end
    end

    if get(kwargs, :add_reserves, false)
        reserve_uc = reserve5(get_components(ThermalStandard, c_sys5_uc))
        add_service!(c_sys5_uc, reserve_uc[1], get_components(ThermalStandard, c_sys5_uc))
        add_service!(
            c_sys5_uc,
            reserve_uc[2],
            [collect(get_components(ThermalStandard, c_sys5_uc))[end]],
        )
        add_service!(c_sys5_uc, reserve_uc[3], get_components(ThermalStandard, c_sys5_uc))
        # ORDC Curve
        add_service!(c_sys5_uc, reserve_uc[4], get_components(ThermalStandard, c_sys5_uc))
        for serv in get_components(VariableReserve, c_sys5_uc)
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[t])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_uc, serv, Deterministic("requirement", forecast_data))
        end
        for (ix, serv) in enumerate(get_components(ReserveDemandCurve, c_sys5_uc))
            forecast_data = SortedDict{Dates.DateTime, Vector{IS.PWL}}()
            for t in 1:2
                ini_time = timestamp(ORDC_cost_ts[t])[1]
                forecast_data[ini_time] = TimeSeries.values(ORDC_cost_ts[t])
            end
            resolution = timestamp(ORDC_cost_ts[1])[2] - timestamp(ORDC_cost_ts[1])[1]
            set_variable_cost!(
                c_sys5_uc,
                serv,
                Deterministic("variable_cost", forecast_data, resolution),
            )
        end
    end

    return c_sys5_uc
end

function build_c_sys5_pwl_uc(; kwargs...)
    c_sys5_uc = build_c_sys5_uc(; kwargs...)
    thermal = thermal_generators5_pwl(collect(get_components(Bus, c_sys5_uc)))
    for d in thermal
        PSY.add_component!(c_sys5_uc, d)
    end
    return c_sys5_uc
end

function build_c_sys5_ed(; kwargs...)
    nodes = nodes5()
    c_sys5_ed = System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2 # loop over days
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta) # loop over hours
                    ini_time = timestamp(ta[i]) #get the hour
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(c_sys5_ed, l, Deterministic("max_active_power", forecast_data))
        end
        for (ix, l) in enumerate(get_components(RenewableGen, c_sys5_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2 # loop over days
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta) # loop over hours
                    ini_time = timestamp(ta[i]) #get the hour
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(c_sys5_ed, l, Deterministic("max_active_power", forecast_data))
        end
        for (ix, l) in enumerate(get_components(InterruptibleLoad, c_sys5_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2 # loop over days
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta) # loop over hours
                    ini_time = timestamp(ta[i]) #get the hour
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(c_sys5_ed, l, Deterministic("max_active_power", forecast_data))
        end
    end

    return c_sys5_ed
end

function build_c_sys5_pwl_ed(; kwargs...)
    c_sys5_ed = build_c_sys5_ed(; kwargs...)
    thermal = thermal_generators5_pwl(collect(get_components(Bus, c_sys5_ed)))
    for d in thermal
        PSY.add_component!(c_sys5_ed, d)
    end
    return c_sys5_ed
end

function build_c_sys5_pwl_ed_nonconvex(; kwargs...)
    c_sys5_ed = build_c_sys5_ed(; kwargs...)
    thermal = thermal_generators5_pwl_nonconvex(collect(get_components(Bus, c_sys5_ed)))
    for d in thermal
        PSY.add_component!(c_sys5_ed, d)
    end
    return c_sys5_ed
end

function build_init(gens, data)
    init = Vector{InitialCondition}(undef, length(collect(gens)))
    for (ix, g) in enumerate(gens)
        init[ix] = InitialCondition(
            g,
            PSI.UpdateRef{JuMP.VariableRef}(PSI.ACTIVE_POWER),
            data[ix],
            TimeStatusChange,
        )
    end
    return init
end

function build_c_sys5_hy_uc(; kwargs...)
    nodes = nodes5()
    c_sys5_hy_uc = System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        hydro_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hy_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hy_uc,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hy_uc,
                h,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hy_uc,
                h,
                Deterministic("storage_capacity", forecast_data),
            )
            add_time_series!(
                c_sys5_hy_uc,
                h,
                Deterministic("storage_target", forecast_data),
            )
        end
        for (ix, h) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix] .* 0.8
            end
            add_time_series!(c_sys5_hy_uc, h, Deterministic("inflow", forecast_data))
        end
        for (ix, h) in enumerate(get_components(HydroDispatch, c_sys5_hy_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(hydro_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = hydro_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hy_uc,
                h,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, r) in enumerate(get_components(RenewableGen, c_sys5_hy_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(ren_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = ren_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hy_uc,
                r,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, i) in enumerate(get_components(InterruptibleLoad, c_sys5_hy_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Iload_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = Iload_timeseries_DA[t][ix]
            end
            add_time_series!(
                c_sys5_hy_uc,
                i,
                Deterministic("max_active_power", forecast_data),
            )
        end
    end

    return c_sys5_hy_uc
end

function build_c_sys5_hy_ed(; kwargs...)
    nodes = nodes5()
    c_sys5_hy_ed = System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        hydro_generators5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_hy_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2 # loop over days
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta) # loop over hours
                    ini_time = timestamp(ta[i]) #get the hour
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_hy_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = hydro_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_hy_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(RenewableGen, c_sys5_hy_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_hy_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = hydro_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_hy_ed,
                l,
                Deterministic("storage_capacity", forecast_data),
            )
            add_time_series!(
                c_sys5_hy_ed,
                l,
                Deterministic("storage_target", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(HydroEnergyReservoir, c_sys5_hy_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = hydro_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hydro_timeseries_RT[t][ix] .* 0.8, hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(c_sys5_hy_ed, l, Deterministic("inflow", forecast_data))
        end
        for (ix, l) in enumerate(get_components(InterruptibleLoad, c_sys5_hy_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_hy_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(HydroDispatch, c_sys5_hy_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = hydro_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_hy_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
    end

    return c_sys5_hy_ed
end

function build_c_sys5_phes_ed(; kwargs...)
    nodes = nodes5()
    c_sys5_phes_ed = System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        phes5(nodes),
        renewable_generators5(nodes),
        loads5(nodes),
        interruptible(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_phes_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2 # loop over days
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta) # loop over hours
                    ini_time = timestamp(ta[i]) #get the hour
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1])) # get the subset ts for that hour
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_phes_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(HydroGen, c_sys5_phes_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = hydro_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_phes_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(RenewableGen, c_sys5_phes_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_phes_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(HydroPumpedStorage, c_sys5_phes_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = hydro_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hydro_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_phes_ed,
                l,
                Deterministic("storage_capacity", forecast_data),
            )
        end
        for (ix, l) in enumerate(get_components(HydroPumpedStorage, c_sys5_phes_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = hydro_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(hydro_timeseries_RT[t][ix] .* 0.8, hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(c_sys5_phes_ed, l, Deterministic("inflow", forecast_data))
            add_time_series!(c_sys5_phes_ed, l, Deterministic("outflow", forecast_data))
        end
        for (ix, l) in enumerate(get_components(InterruptibleLoad, c_sys5_phes_ed))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ta = load_timeseries_DA[t][ix]
                for i in 1:length(ta)
                    ini_time = timestamp(ta[i])
                    data = when(load_timeseries_RT[t][ix], hour, hour(ini_time[1]))
                    forecast_data[ini_time[1]] = data
                end
            end
            add_time_series!(
                c_sys5_phes_ed,
                l,
                Deterministic("max_active_power", forecast_data),
            )
        end
    end

    return c_sys5_phes_ed
end

function build_c_sys5_pglib(; kwargs...)
    nodes = nodes5()
    c_sys5_uc = System(
        100.0,
        nodes,
        thermal_generators5_uc_testing(nodes),
        thermal_pglib_generators5(nodes),
        loads5(nodes),
        branches5(nodes);
        time_series_in_memory = get(kwargs, :time_series_in_memory, true),
    )

    if get(kwargs, :add_forecasts, true)
        forecast_data = SortedDict{Dates.DateTime, TimeArray}()
        for (ix, l) in enumerate(get_components(PowerLoad, c_sys5_uc))
            for t in 1:2
                ini_time = timestamp(load_timeseries_DA[t][ix])[1]
                forecast_data[ini_time] = load_timeseries_DA[t][ix]
            end
            add_time_series!(c_sys5_uc, l, Deterministic("max_active_power", forecast_data))
        end
    end

    if get(kwargs, :add_reserves, false)
        reserve_uc = reserve5(get_components(ThermalStandard, c_sys5_uc))
        add_service!(c_sys5_uc, reserve_uc[1], get_components(ThermalStandard, c_sys5_uc))
        add_service!(
            c_sys5_uc,
            reserve_uc[2],
            [collect(get_components(ThermalStandard, c_sys5_uc))[end]],
        )
        add_service!(c_sys5_uc, reserve_uc[3], get_components(ThermalStandard, c_sys5_uc))
        for (ix, serv) in enumerate(get_components(VariableReserve, c_sys5_uc))
            forecast_data = SortedDict{Dates.DateTime, TimeArray}()
            for t in 1:2
                ini_time = timestamp(Reserve_ts[ix])[1]
                forecast_data[ini_time] = Reserve_ts[t]
            end
            add_time_series!(c_sys5_uc, serv, Deterministic("requirement", forecast_data))
        end
    end

    return c_sys5_uc
end

function build_sos_test_sys(; kwargs...)
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 100.0, 1.0, 2.0)
    gens_cost_sos = [
        ThermalStandard(
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            active_power = 0.52,
            reactive_power = 0.010,
            rating = 0.5,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.22, max = 0.55),
            reactive_power_limits = nothing,
            time_limits = nothing,
            ramp_limits = nothing,
            operation_cost = ThreePartCost(
                [(1122.43, 22.0), (1617.43, 33.0), (1742.48, 44.0), (2075.88, 55.0)],
                0.0,
                5665.23,
                0.0,
            ),
            base_power = 100.0,
        ),
        ThermalStandard(
            name = "Park City",
            available = true,
            status = true,
            bus = node,
            active_power = 0.62,
            reactive_power = 0.20,
            rating = 2.2125,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.62, max = 1.55),
            reactive_power_limits = nothing,
            time_limits = nothing,
            ramp_limits = nothing,
            operation_cost = ThreePartCost(
                [(1500.19, 62.0), (2132.59, 92.9), (2829.875, 124.0), (2831.444, 155.0)],
                0.0,
                5665.23,
                0.0,
            ),
            base_power = 100.0,
        ),
    ]

    #Checks the data remains non-convex
    for g in gens_cost_sos
        @assert PSI.pwlparamcheck(PSY.get_operation_cost(g).variable) == false
    end

    DA_load_forecast = SortedDict{Dates.DateTime, TimeArray}()
    ini_time = DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S")
    cost_sos_load = [[1.3, 2.1], [1.3, 2.1]]
    for (ix, date) in enumerate(range(ini_time; length = 2, step = Hour(1)))
        DA_load_forecast[date] = TimeArray([date, date + Hour(1)], cost_sos_load[ix])
    end
    load_forecast_cost_sos = Deterministic("max_active_power", DA_load_forecast)
    cost_test_sos_sys =
        System(100.0; time_series_in_memory = get(kwargs, :time_series_in_memory, true))
    add_component!(cost_test_sos_sys, node)
    add_component!(cost_test_sos_sys, load)
    add_component!(cost_test_sos_sys, gens_cost_sos[1])
    add_component!(cost_test_sos_sys, gens_cost_sos[2])
    add_time_series!(cost_test_sos_sys, load, load_forecast_cost_sos)

    return cost_test_sos_sys
end

function build_pwl_test_sys(; kwargs...)
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 100.0, 1.0, 2.0)
    gens_cost = [
        ThermalStandard(
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            active_power = 0.52,
            reactive_power = 0.010,
            rating = 0.5,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.22, max = 0.55),
            reactive_power_limits = nothing,
            time_limits = nothing,
            ramp_limits = nothing,
            operation_cost = ThreePartCost(
                [(589.99, 22.0), (884.99, 33.0), (1210.04, 44.0), (1543.44, 55.0)],
                532.44,
                5665.23,
                0.0,
            ),
            base_power = 100.0,
        ),
        ThermalStandard(
            name = "Park City",
            available = true,
            status = true,
            bus = node,
            active_power = 0.62,
            reactive_power = 0.20,
            rating = 221.25,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.62, max = 1.55),
            reactive_power_limits = nothing,
            time_limits = nothing,
            ramp_limits = nothing,
            operation_cost = ThreePartCost(
                [(1264.80, 62.0), (1897.20, 93.0), (2594.4787, 124.0), (3433.04, 155.0)],
                235.397,
                5665.23,
                0.0,
            ),
            base_power = 100.0,
        ),
    ]

    DA_load_forecast = SortedDict{Dates.DateTime, TimeArray}()
    ini_time = DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S")
    cost_sos_load = [[1.3, 2.1], [1.3, 2.1]]
    for (ix, date) in enumerate(range(ini_time; length = 2, step = Hour(1)))
        DA_load_forecast[date] = TimeArray([date, date + Hour(1)], cost_sos_load[ix])
    end
    load_forecast_cost_sos = Deterministic("max_active_power", DA_load_forecast)
    cost_test_sys =
        System(100.0; time_series_in_memory = get(kwargs, :time_series_in_memory, true))
    add_component!(cost_test_sys, node)
    add_component!(cost_test_sys, load)
    add_component!(cost_test_sys, gens_cost[1])
    add_component!(cost_test_sys, gens_cost[2])
    add_time_series!(cost_test_sys, load, load_forecast_cost_sos)
    return cost_test_sys
end

function build_duration_test_sys(; kwargs...)
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 100.0, 1.0, 2.0)
    DA_dur = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  6:00:00",
            "d/m/y  H:M:S",
        ),
    )
    gens_dur = [
        ThermalStandard(
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            active_power = 0.40,
            reactive_power = 0.010,
            rating = 0.5,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.3, max = 0.9),
            reactive_power_limits = nothing,
            ramp_limits = nothing,
            time_limits = (up = 4, down = 2),
            operation_cost = ThreePartCost((0.0, 14.0), 0.0, 4.0, 2.0),
            base_power = 100.0,
            time_at_status = 2.0,
        ),
        ThermalStandard(
            name = "Park City",
            available = true,
            status = false,
            bus = node,
            active_power = 1.70,
            reactive_power = 0.20,
            rating = 2.2125,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.7, max = 2.2),
            reactive_power_limits = nothing,
            ramp_limits = nothing,
            time_limits = (up = 6, down = 4),
            operation_cost = ThreePartCost((0.0, 15.0), 0.0, 1.5, 0.75),
            base_power = 100.0,
            time_at_status = 3.0,
        ),
    ]

    duration_load = [0.3, 0.6, 0.8, 0.7, 1.7, 0.9, 0.7]
    load_data = SortedDict(DA_dur[1] => TimeArray(DA_dur, duration_load))
    load_forecast_dur = Deterministic("max_active_power", load_data)
    duration_test_sys =
        System(100.0; time_series_in_memory = get(kwargs, :time_series_in_memory, true))
    add_component!(duration_test_sys, node)
    add_component!(duration_test_sys, load)
    add_component!(duration_test_sys, gens_dur[1])
    add_component!(duration_test_sys, gens_dur[2])
    add_time_series!(duration_test_sys, load, load_forecast_dur)

    return duration_test_sys
end

function build_pwl_marketbid_sys(; kwargs...)
    node = Bus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing)
    load = PowerLoad("Bus1", true, node, nothing, 0.4, 0.9861, 100.0, 1.0, 2.0)
    gens_cost = [
        ThermalStandard(
            name = "Alta",
            available = true,
            status = true,
            bus = node,
            active_power = 0.52,
            reactive_power = 0.010,
            rating = 0.5,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.22, max = 0.55),
            reactive_power_limits = nothing,
            time_limits = nothing,
            ramp_limits = nothing,
            operation_cost = MarketBidCost(
                no_load = 0.0,
                start_up = (hot = 0.0, warm = 0.0, cold = 0.0),
                shut_down = 0.0,
            ),
            base_power = 100.0,
        ),
        ThermalMultiStart(
            name = "115_STEAM_1",
            available = true,
            status = true,
            bus = node,
            active_power = 0.05,
            reactive_power = 0.010,
            rating = 0.12,
            prime_mover = PrimeMovers.ST,
            fuel = ThermalFuels.COAL,
            active_power_limits = (min = 0.05, max = 0.12),
            reactive_power_limits = (min = -0.30, max = 0.30),
            ramp_limits = (up = 0.2 * 0.12, down = 0.2 * 0.12),
            power_trajectory = (startup = 0.05, shutdown = 0.05),
            time_limits = (up = 4.0, down = 2.0),
            start_time_limits = (hot = 2.0, warm = 4.0, cold = 12.0),
            start_types = 3,
            operation_cost = MarketBidCost(
                no_load = 0.0,
                start_up = (hot = 393.28, warm = 455.37, cold = 703.76),
                shut_down = 0.0,
            ),
            base_power = 100.0,
        ),
    ]
    ini_time = DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S")
    DA_load_forecast = Dict{Dates.DateTime, TimeArray}()
    market_bid_gen1_data = Dict(
        ini_time => [
            [(589.99, 22.0), (884.99, 33.0), (1210.04, 44.0), (1543.44, 55.0)],
            [(589.99, 22.0), (884.99, 33.0), (1210.04, 44.0), (1543.44, 55.0)],
        ],
        ini_time + Hour(1) => [
            [(589.99, 22.0), (884.99, 33.0), (1210.04, 44.0), (1543.44, 55.0)],
            [(589.99, 22.0), (884.99, 33.0), (1210.04, 44.0), (1543.44, 55.0)],
        ],
    )
    market_bid_gen1 = Deterministic(
        name = "variable_cost",
        data = market_bid_gen1_data,
        resolution = Hour(1),
    )
    market_bid_gen2_data = Dict(
        ini_time => [
            [(0.0, 5.0), (290.1, 7.33), (582.72, 9.67), (894.1, 12.0)],
            [(0.0, 5.0), (300.1, 7.33), (600.72, 9.67), (900.1, 12.0)],
        ],
        ini_time + Hour(1) => [
            [(0.0, 5.0), (290.1, 7.33), (582.72, 9.67), (894.1, 12.0)],
            [(0.0, 5.0), (300.1, 7.33), (600.72, 9.67), (900.1, 12.0)],
        ],
    )
    market_bid_gen2 = Deterministic(
        name = "variable_cost",
        data = market_bid_gen2_data,
        resolution = Hour(1),
    )
    market_bid_load = [[1.3, 2.1], [1.3, 2.1]]
    for (ix, date) in enumerate(range(ini_time; length = 2, step = Hour(1)))
        DA_load_forecast[date] = TimeArray([date, date + Hour(1)], market_bid_load[ix])
    end
    load_forecast_cost_market_bid = Deterministic("max_active_power", DA_load_forecast)
    cost_test_sys =
        System(100.0; time_series_in_memory = get(kwargs, :time_series_in_memory, true))
    add_component!(cost_test_sys, node)
    add_component!(cost_test_sys, load)
    add_component!(cost_test_sys, gens_cost[1])
    add_component!(cost_test_sys, gens_cost[2])
    add_time_series!(cost_test_sys, load, load_forecast_cost_market_bid)
    set_variable_cost!(cost_test_sys, gens_cost[1], market_bid_gen1)
    set_variable_cost!(cost_test_sys, gens_cost[2], market_bid_gen2)
    return cost_test_sys
end

TEST_SYSTEMS = Dict(
    "c_sys14" => (
        description = "14-bus system",
        build = build_c_sys14,
        time_series_in_memory = true,
    ),
    "c_sys14_dc" => (
        description = "14-bus system with DC line",
        build = build_c_sys14_dc,
        time_series_in_memory = true,
    ),
    "c_sys5" => (
        description = "5-bus system",
        build = build_c_sys5,
        time_series_in_memory = true,
    ),
    "c_sys5_bat" => (
        description = "5-bus system with Storage Device",
        build = build_c_sys5_bat,
        time_series_in_memory = true,
    ),
    "c_sys5_bat_ems" => (
        description = "5-bus system with Storage Device",
        build = build_c_sys5_bat_ems,
        time_series_in_memory = true,
    ),
    "c_sys5_dc" => (
        description = "Systems with HVDC data in the branches",
        build = build_c_sys5_dc,
        time_series_in_memory = true,
    ),
    "c_sys5_ed" =>
        (description = "", build = build_c_sys5_ed, time_series_in_memory = true),
    "c_sys5_hy" => (
        description = "5-bus system with HydroPower Energy",
        build = build_c_sys5_hy,
        time_series_in_memory = true,
    ),
    "c_sys5_hy_ed" =>
        (description = "", build = build_c_sys5_hy_ed, time_series_in_memory = true),
    "c_sys5_phes_ed" =>
        (description = "", build = build_c_sys5_phes_ed, time_series_in_memory = true),
    "c_sys5_hy_uc" =>
        (description = "", build = build_c_sys5_hy_uc, time_series_in_memory = true),
    "c_sys5_hyd" =>
        (description = "", build = build_c_sys5_hyd, time_series_in_memory = true),
    "c_sys5_il" => (
        description = "System with Interruptible Load",
        build = build_c_sys5_il,
        time_series_in_memory = true,
    ),
    "c_sys5_ml" =>
        (description = "", build = build_c_sys5_ml, time_series_in_memory = true),
    "c_sys5_re" => (
        description = "5-bus system with Renewable Energy",
        build = build_c_sys5_re,
        time_series_in_memory = true,
    ),
    "c_sys5_re_only" =>
        (description = "", build = build_c_sys5_re_only, time_series_in_memory = true),
    "c_sys5_uc" =>
        (description = "", build = build_c_sys5_uc, time_series_in_memory = true),
    "c_sys5_pglib" => (
        description = "5-bus with ThermalMultiStart",
        build = build_c_sys5_pglib,
        time_series_in_memory = true,
    ),
    "c_sys5_pwl_uc" => (
        description = "5-bus with SOS cost function",
        build = build_c_sys5_pwl_uc,
        time_series_in_memory = true,
    ),
    "c_sys5_pwl_ed" => (
        description = "5-bus with pwl cost function",
        build = build_c_sys5_pwl_ed,
        time_series_in_memory = true,
    ),
    "c_sys5_pwl_ed_nonconvex" => (
        description = "5-bus with SOS cost function",
        build = build_c_sys5_pwl_ed_nonconvex,
        time_series_in_memory = true,
    ),
    "c_sys5_reg" => (
        description = "5-bus with regulation devices and AGC",
        build = build_c_sys5_reg,
        time_series_in_memory = true,
    ),
    "c_ramp_test" => (
        description = "1-bus for ramp testing",
        build = build_sys_ramp_testing,
        time_series_in_memory = true,
    ),
    "c_duration_test" => (
        description = "1 Bus for durantion testing",
        build = build_duration_test_sys,
        time_series_in_memory = true,
    ),
    "c_linear_pwl_test" => (
        description = "1 Bus lineal PWL linear testing",
        build = build_pwl_test_sys,
        time_series_in_memory = true,
    ),
    "c_sos_pwl_test" => (
        description = "1 Bus lineal PWL sos testing",
        build = build_sos_test_sys,
        time_series_in_memory = true,
    ),
    "c_market_bid_cost" => (
        description = "1 bus system with MarketBidCost Model",
        build = build_pwl_marketbid_sys,
        time_series_in_memory = true,
    ),
)

build_PTDF5() = PTDF(build_system("c_sys5"))
build_PTDF14() = PTDF(build_system("c_sys14"))
build_PTDF5_dc() = PTDF(build_system("c_sys5_dc"))
build_PTDF14_dc() = PTDF(build_system("c_sys14_dc"))
