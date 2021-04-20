"""
Stores simulation data for one problem.
"""
mutable struct ProblemData
    duals::Dict{Symbol, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    parameters::Dict{Symbol, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
    variables::Dict{Symbol, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}
end

function ProblemData()
    return ProblemData(
        Dict{Symbol, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}(),
        Dict{Symbol, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}(),
        Dict{Symbol, OrderedDict{Dates.DateTime, DataFrames.DataFrame}}(),
    )
end

"""
Stores simulation data in memory
"""
mutable struct InMemorySimulationStore <: SimulationStore
    params::SimulationStoreParams
    data::OrderedDict{Symbol, ProblemData}
    # The key is the problem name.
    optimizer_stats::Dict{Symbol, OrderedDict{Dates.DateTime, OptimizerStats}}
end

function InMemorySimulationStore()
    return InMemorySimulationStore(
        SimulationStoreParams(),
        OrderedDict{Symbol, ProblemData}(),
        Dict{Symbol, OrderedDict{Dates.DateTime, OptimizerStats}}(),
    )
end

function open_store(
    func::Function,
    ::Type{InMemorySimulationStore},
    directory::AbstractString,  # Unused. Need to match the interface.
    mode = nothing,
    filename = nothing,
)
    store = InMemorySimulationStore()
    return func(store)
end

function Base.empty!(store::InMemorySimulationStore)
    for problem_data in values(store.data)
        for type in STORE_CONTAINERS
            container = getfield(problem_data, type)
            for dict in values(container)
                empty!(dict)
            end
        end
    end

    empty!(store.optimizer_stats)
    @debug "Emptied the store"
end

Base.isopen(store::InMemorySimulationStore) = true
Base.close(store::InMemorySimulationStore) = nothing
Base.flush(store::InMemorySimulationStore) = nothing
get_params(store::InMemorySimulationStore) = store.params

list_problems(store::InMemorySimulationStore) = keys(store.data)
log_cache_hit_percentages(InMemorySimulationStore) = nothing

function list_fields(
    store::InMemorySimulationStore,
    problem::Symbol,
    container_type::Symbol,
)
    container = getfield(store.data[problem], container_type)
    return keys(container)
end

function write_optimizer_stats!(
    store::InMemorySimulationStore,
    problem,
    stats::OptimizerStats,
    timestamp,
)
    store.optimizer_stats[Symbol(problem)][timestamp] = stats
    return
end

function read_problem_optimizer_stats(
    store::InMemorySimulationStore,
    simulation_step,
    problem,
    timestamp,
)
    _check_timestamp(store.optimizer_stats, timestamp)
    return store.optimizer_stats[problem][timestamp]
end

function read_problem_optimizer_stats(store::InMemorySimulationStore, problem)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats[problem])]
    return DataFrames.DataFrame(stats)
end

function initialize_problem_storage!(
    store::InMemorySimulationStore,
    params,
    problem_reqs,
    flush_rules,
)
    store.params = params
    @debug "initialize_problem_storage"

    for problem in keys(store.params.problems)
        store.data[problem] = ProblemData()
        for type in STORE_CONTAINERS
            for (name, reqs) in getfield(problem_reqs[problem], type)
                container = getfield(store.data[problem], type)
                container[name] = OrderedDict{Dates.DateTime, DataFrames.DataFrame}()
            end
        end

        store.optimizer_stats[problem] = OrderedDict{Dates.DateTime, OptimizerStats}()
        @debug "Initialized optimizer_stats_datasets $problem"
    end
end

function write_result!(
    store::InMemorySimulationStore,
    problem_name,
    container_type,
    name,
    timestamp,
    array,
    columns = nothing,
)
    container = getfield(store.data[Symbol(problem_name)], container_type)
    container[name][timestamp] = axis_array_to_dataframe(array, columns)
    return
end

function read_result(
    ::Type{DataFrames.DataFrame},
    store::InMemorySimulationStore,
    problem_name,
    container_type,
    name,
    timestamp::Dates.DateTime,
)
    return read_result(store, problem_name, container_type, name, timestamp)
end

function read_result(
    store::InMemorySimulationStore,
    problem_name,
    container_type,
    name,
    timestamp::Dates.DateTime,
)
    container = getfield(store.data[Symbol(problem_name)], container_type)[name]
    _check_timestamp(container, timestamp)
    # Return a copy because callers may mutate it. SimulationProblemResults adds timestamps.
    return copy(container[timestamp], copycols = true)
end

function _check_timestamp(dict::AbstractDict, timestamp::Dates.DateTime)
    if !haskey(dict, timestamp)
        throw(IS.InvalidValue("timestamp = $timestamp is not stored"))
    end
end
