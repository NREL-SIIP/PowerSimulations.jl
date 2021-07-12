struct Settings
    horizon::Base.RefValue{Int}
    time_series_cache_size::Int
    warm_start::Base.RefValue{Bool}
    initial_time::Base.RefValue{Dates.DateTime}
    optimizer::Union{Nothing, MOI.OptimizerWithAttributes}
    direct_mode_optimizer::Bool
    optimizer_log_print::Bool
    system_to_file::Bool
    export_pwl_vars::Bool
    allow_fails::Bool
    ext::Dict{String, Any}
end

function Settings(
    sys;
    initial_time::Dates.DateTime = UNSET_INI_TIME,
    time_series_cache_size::Int = IS.TIME_SERIES_CACHE_SIZE_BYTES,
    warm_start::Bool = true,
    horizon::Int = UNSET_HORIZON,
    optimizer = nothing,
    direct_mode_optimizer::Bool = false,
    optimizer_log_print::Bool = false,
    system_to_file = true,
    export_pwl_vars = false,
    allow_fails = false,
    ext = Dict{String, Any}(),
)
    if time_series_cache_size > 0 &&
       sys.data.time_series_storage isa IS.InMemoryTimeSeriesStorage
        @info "Overriding time_series_cache_size because time series is stored in memory"
        time_series_cache_size = 0
    end

    if isa(optimizer, MOI.OptimizerWithAttributes) || optimizer === nothing
        optimizer_ = optimizer
    elseif isa(optimizer, DataType)
        optimizer_ = MOI.OptimizerWithAttributes(optimizer)
    else
        error(
            "The provided input for optimizer is invalid. Provide a JuMP.OptimizerWithAttributes object or a valid Optimizer constructor (e.g. GLPK.Optimizer).",
        )
    end

    return Settings(
        Ref(horizon),
        time_series_cache_size,
        Ref(warm_start),
        Ref(initial_time),
        optimizer_,
        direct_mode_optimizer,
        optimizer_log_print,
        system_to_file,
        export_pwl_vars,
        allow_fails,
        ext,
    )
end

function log_values(settings::Settings)
    text = Vector{String}()
    for (name, type) in zip(fieldnames(Settings), fieldtypes(Settings))
        val = getfield(settings, name)
        if type <: Base.RefValue
            val = val[]
        end
        push!(text, "$name = $val")
    end

    @debug "Settings: $(join(text, ", "))"
end

function copy_for_serialization(settings::Settings)
    vals = []
    for name in fieldnames(Settings)
        if name == :optimizer
            # Cannot guarantee that the optimizer can be serialized.
            val = nothing
        else
            val = getfield(settings, name)
        end

        push!(vals, val)
    end

    return deepcopy(Settings(vals...))
end

function restore_from_copy(
    settings::Settings;
    optimizer::Union{Nothing, MOI.OptimizerWithAttributes},
)
    vals = Dict{Symbol, Any}()
    for name in fieldnames(Settings)
        if name == :optimizer
            vals[name] = optimizer
        elseif name == :ext
            continue
        else
            val = getfield(settings, name)
            vals[name] = isa(val, Base.RefValue) ? val[] : val
        end
    end

    return vals
end

get_horizon(settings::Settings) = settings.horizon[]
get_initial_time(settings::Settings)::Dates.DateTime = settings.initial_time[]
get_optimizer(settings::Settings) = settings.optimizer
get_ext(settings::Settings) = settings.ext
get_warm_start(settings::Settings) = settings.warm_start[]
get_system_to_file(settings::Settings) = settings.system_to_file
get_export_pwl_vars(settings::Settings) = settings.export_pwl_vars
get_allow_fails(settings::Settings) = settings.allow_fails
get_optimizer_log_print(settings::Settings) = settings.optimizer_log_print
get_direct_mode_optimizer(settings::Settings) = settings.direct_mode_optimizer
use_time_series_cache(settings::Settings) = settings.time_series_cache_size > 0

function set_horizon!(settings::Settings, horizon::Int)
    settings.horizon[] = horizon
    return
end

function set_initial_time!(settings::Settings, initial_time::Dates.DateTime)
    settings.initial_time[] = initial_time
    return
end

function set_warm_start!(settings::Settings, warm_start::Bool)
    settings.warm_start[] = warm_start
    return
end
