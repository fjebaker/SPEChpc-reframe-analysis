abstract type AbstractMeasurement end

get_metric(::AbstractMeasurement, ::AbstractRunInfo) = error("Not implemented")
get_timeseries(::AbstractMeasurement, ::AbstractRunInfo) = error("Not implemented")

struct Perf <: AbstractMeasurement end
struct BMC <: AbstractMeasurement end

function get_metric(::Perf, info::AbstractRunInfo)
    # sum all sockets, all nodes, all pkg and ram
    pkgs = get_all_metric("energy-pkg", info)
    rams = get_all_metric("energy-ram", info)
    (sum(pkgs) + sum(rams))
end

function get_metric(::BMC, info::AbstractRunInfo)
    get_metric("BMC", info)
end

function get_timeseries(::Perf, info::AbstractRunInfo)
    time_pkgs = _get_all_timeseries("energy-pkg", info)
    time_rams = _get_all_timeseries("energy-ram", info)

    # assumes the time series are the same for ram and pkg
    times = first(first.(time_pkgs))

    pkgs = stack_as_matrix(last.(time_pkgs))
    rams = stack_as_matrix(last.(time_rams))

    total = sum(pkgs, dims = 2) .+ sum(rams, dims = 2)
    (times, vec(total))
end

function get_timeseries(::BMC, info::AbstractRunInfo)
    times, total = _get_timeseries("BMC", info)
    (times, total)
end

abstract type AbstractMetric end
format_label(m::AbstractMetric) = "$(Base.typename(typeof(m)).name) ($(m.unit))"
filter_runinfos(::AbstractMetric, infos::Vector{<:AbstractRunInfo}) = infos

# permit broadcasting
Base.broadcastable(m::AbstractMetric) = Ref(m)

reduction_f(::AbstractMetric) = mean

# get_series_for(m::AbstractMetric, partition) =
#     get_series_for(m, get_iv.(partition), partition)

struct BinnedValues{M <: AbstractMetric,T,V}
    metric::M
    bins::Vector{T}
    values::Vector{V}
end

Base.show(io::IO, ::MIME"text/plain", r::BinnedValues) =
    print(io, r)
function Base.show(io::IO, r::BinnedValues{M}) where {M}
    print(io, "BinnedValues{$(M),n=$(length(r.bins))}")
end

function get_metric(m::AbstractMetric, infos::Vector{<:AbstractRunInfo})
    ivs = get_iv.(infos)
    values = get_metric.(m, infos)
    bins, weights = bin_independent_variable(ivs, values)
    BinnedValues(m, bins, weights)
end

struct SeriesValues{M <: AbstractMetric,T,B}
    metric::M
    times::Vector{T}
    values::Vector{T}
    bins::Vector{B}
end

Base.show(io::IO, ::MIME"text/plain", r::SeriesValues) =
    print(io, r)
function Base.show(io::IO, r::SeriesValues{M}) where {M}
    print(io, "SeriesValues{$(M),n=$(length(r.times))}")
end

function time_series(m::AbstractMetric, infos::Vector{<:AbstractRunInfo})
    ivs = get_iv.(infos)
    data = time_series.(m, infos)
    times = first.(data)
    values = last.(data)
    SeriesValues(m, times, values, ivs)
end


###############################################################################

struct Power{F,M} <: AbstractMetric
    scale::Float64
    unit::String
    reduction::F
    measurement::M
end

Power(; reduction = maximum, measurement = BMC()) = Power(1e3, "kW", reduction, measurement)

format_label(m::Power) =
    "$(Base.typename(typeof(m.reduction)).name) $(Base.typename(typeof(m)).name) ($(m.unit))"

reduction_f(m::Power) = m.reduction

function time_series(m::Power, info::AbstractRunInfo)
    _to_powerseries(m.measurement, get_timeseries(m.measurement, info))
end

function get_metric(m::Power, info::AbstractRunInfo)
    _, values = time_series(m, info)
    reduction_f(m)(values)
end

###############################################################################

struct Energy{M} <: AbstractMetric
    scale::Float64
    unit::String
    measurement::M
end

Energy(; measurement = BMC()) = Energy(1e3, "kJ", measurement)

function time_series(m::Energy, info::AbstractRunInfo)
    if m.measurement isa BMC
        throw("Cannot produce energy series for BMC")
    end
    time, energies = get_timeseries(m.measurement, info)
    time, vec(energies)
end

function get_metric(m::Energy, info::AbstractRunInfo)
    if m.measurement isa BMC
        time, power = get_timeseries(BMC(), info)
        integrate(time, power)
    else
        get_metric(m.measurement, info)
    end
end

###############################################################################

struct PowerSaving{P} <: AbstractMetric
    power::P
end

PowerSaving(; kwargs...) = PowerSaving(Power(; kwargs...))

format_label(m::PowerSaving) =
    "$(Base.typename(typeof(m.power.reduction)).name) Power Saving (rel)"

function get_series_for(m::PowerSaving, ivs, partition)
    f(row) = inv.(row ./ maximum(row))
    series = get_series_for(Power(m.scale, m.unit, m.reduction), ivs, partition)
    perf = aggregate_stat(f, series.perf)
    bmc = aggregate_stat(f, series.bmc)
    (; bins = series.bins, perf = perf, bmc = bmc)
end


###############################################################################

struct EnergySaving{E} <: AbstractMetric
    energy::E
end

EnergySaving(; kwargs...) = EnergySaving(Energy(; kwargs...))

format_label(m::EnergySaving) = "Energy Saving (rel)"

function get_series_for(m::EnergySaving, ivs, partition)
    f(row) = inv.(row ./ maximum(row))
    series = get_series_for(Energy(m.scale, m.unit), ivs, partition)
    perf = aggregate_stat(f, series.perf)
    bmc = aggregate_stat(f, series.bmc)
    (; bins = series.bins, perf = perf, bmc = bmc)
end

###############################################################################

struct Slowdown <: AbstractMetric
    scale::Float64
    unit::String
end

Slowdown() = Slowdown(1.0, "rel.")

function get_series_for(::Slowdown, ivs, partition)
    times = get_series_for(Runtime(), ivs, partition)
    f(row) = (row ./ minimum(row))
    speedup = aggregate_stat(f, times.time)
    (; bins = times.bins, time = speedup)
end

###############################################################################

struct Speedup <: AbstractMetric
    scale::Float64
    unit::String
end


Speedup() = Speedup(1.0, "rel.")

function get_series_for(::Speedup, ivs, partition)
    times = get_series_for(Runtime(), ivs, partition)
    f(row) = inv.(row ./ maximum(row))
    speedup = aggregate_stat(f, times.time)
    (; bins = times.bins, time = speedup)
end


###############################################################################

struct Runtime <: AbstractMetric
    scale::Float64
    unit::String
end

Runtime() = Runtime(1.0, "s")

function get_series_for(::Runtime, ivs, partition)
    times = totaltime.(partition)
    bins, time_values = bin_independent_variable(ivs, times)
    (; bins = bins, time = time_values)
end

###############################################################################

function bin_independent_variable(ivs, values::Vector{T}) where {T}
    bins = sort(unique(ivs))
@show T
    clusters::Vector{Vector{T}} = [T[] for _ in bins]

    for (f, v) in zip(ivs, values)
        i = findfirst(==(f), bins)
        if !isnothing(i)
            push!(clusters[i], v)
        end
    end

    bins, clusters
end

function aggregate_stat(f, samples)
    shortest = minimum(length, samples)
    all = reduce(hcat, i[1:shortest] for i in samples)
    agg = reduce(hcat, map(f, eachrow(all)))'
    collect(eachcol(agg))
end

function _to_powerseries(::Perf, series)
    time, data = series
    dt = diff(time)[1:end-1]
    time[1:end-2], data[1:end-2] ./ dt
end

_to_powerseries(::BMC, series) = series

struct TargetMetric{M,F} <: AbstractMetric
    metric::M
    target_function::F
end

format_label(m::TargetMetric) = format_label(m.metric)

function find_optimal(target::TargetMetric, partition::Vector{<:AbstractRunInfo})
    ivs = get_iv.(partition)
    unique_freqs, target_series = get_series_for(target.metric, ivs, partition)
    series = mean.(target_series)
    I = target.target_function.(series)

    unique_freqs[I], series[I]
end

function filter_runinfos(target::TargetMetric, partition::Vector{<:AbstractRunInfo})
    ivs, _ = find_optimal(target, partition)
    filter(i -> any(get_iv(i) .≈ ivs), partition)
end

for OP in (:<, :>, :<=, :>=)
    q = quote
        function Base.$(OP)(bi::AbstractMetric, value)
            TargetMetric(bi, i -> $(OP)(i, value))
        end
    end
    eval(q)
end

export Perf,
    BMC,
    Power,
    Energy,
    PowerSaving,
    EnergySaving,
    Speedup,
    Slowdown,
    median,
    mean,
    Runtime,
    get_series_for,
    find_optimal,
    filter_matching,
    time_series,
    get_metric

