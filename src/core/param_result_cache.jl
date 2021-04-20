"""
Cache for a single parameter/variable/dual.
Stores arrays chronologically by simulation timestamp.
"""
mutable struct ParamResultCache
    key::ParamCacheKey
    "Contains both clean and dirty entries. Any key in data that is earlier than the first
    dirty timestamp must be clean."
    data::OrderedDict{Dates.DateTime, Array}
    "Oldest entry is first"
    dirty_timestamps::Deque{Dates.DateTime}
    stats::CacheStats
    size_per_entry::Int
    flush_rule::CacheFlushRule
end

function ParamResultCache(key, flush_rule)
    return ParamResultCache(
        key,
        OrderedDict{Dates.DateTime, Array}(),
        Deque{Dates.DateTime}(),
        CacheStats(),
        0,
        flush_rule,
    )
end

Base.length(x::ParamResultCache) = length(x.data)
get_cache_hit_percentage(x::ParamResultCache) = get_cache_hit_percentage(x.stats)
get_size(x::ParamResultCache) = length(x) * x.size_per_entry
has_clean(x::ParamResultCache) = !isempty(x.data) && !is_dirty(x, first(keys(x.data)))
has_dirty(x::ParamResultCache) = !isempty(x.dirty_timestamps)
should_keep_in_cache(x::ParamResultCache) = x.flush_rule.keep_in_cache

function get_dirty_size(cache::ParamResultCache)
    return length(cache.dirty_timestamps) * cache.size_per_entry
end

function is_dirty(cache::ParamResultCache, timestamp)
    isempty(cache.dirty_timestamps) && return false
    return timestamp >= first(cache.dirty_timestamps)
end

function Base.empty!(cache::ParamResultCache)
    empty!(cache.data)
    empty!(cache.dirty_timestamps)
    cache.size_per_entry = 0
end

"""
Adds thrame result to the cache.
Return true if the cache needs to be flushed.
"""
function add_result!(cache::ParamResultCache, timestamp, array, system_cache_is_full)
    if cache.size_per_entry == 0
        cache.size_per_entry = length(array) * sizeof(first(array))
    end

    @debug "add_result!" cache.key timestamp get_size(cache)
    @assert !haskey(cache.data, timestamp) "$(cache.key) $timestamp"

    if system_cache_is_full
        if has_clean(cache)
            popfirst!(cache.data)
            @debug "replaced cache entry" cache.key
        else
            @error "sys cache is full but there are no clean entries to pop: $(cache.key)"
        end
    end

    _add_result!(cache, timestamp, array)
    return cache.size_per_entry
end

function _add_result!(cache::ParamResultCache, timestamp, data)
    cache.data[timestamp] = data
    push!(cache.dirty_timestamps, timestamp)
end

function discard_results!(cache::ParamResultCache, timestamps)
    for timestamp in timestamps
        pop!(cache.data, timestamp)
    end

    @debug "Removed $(first(timestamps)) - $(last(timestamps)) from cache" cache.key
end

function get_data_to_flush!(cache::ParamResultCache, flush_size)
    num_chunks = flush_size < cache.size_per_entry ? 1 : flush_size ÷ cache.size_per_entry
    num_chunks = minimum((num_chunks, length(cache.dirty_timestamps)))
    @assert_op num_chunks > 0

    timestamps = [popfirst!(cache.dirty_timestamps) for i in 1:num_chunks]
    # Uncomment for performance testing of CacheFlush
    #TimerOutputs.@timeit RUN_SIMULATION_TIMER "Concatenate arrays for flush" begin
    arrays = (cache.data[x] for x in timestamps)
    arrays = cat(arrays..., dims = ndims(first(arrays)) + 1)
    #end

    return timestamps, arrays
end

function has_timestamp(cache::ParamResultCache, timestamp)
    present = haskey(cache.data, timestamp)
    if present
        cache.stats.hits += 1
    else
        cache.stats.misses += 1
    end

    return present
end
