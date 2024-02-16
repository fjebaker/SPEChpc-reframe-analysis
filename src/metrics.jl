abstract type AbstractMetric end
format_label(m::AbstractMetric) = "$(Base.typename(typeof(m)).name) ($(m.unit))"
struct Power{F} <: AbstractMetric
    scale::Float64
    unit::String
    reduction::F
end
Power(;reduction = maximum) = Power(1e3, "kW", reduction)
format_label(m::Power) = "$(Base.typename(typeof(m.reduction)).name) $(Base.typename(typeof(m)).name) ($(m.unit))"
struct PowerSaving{F} <: AbstractMetric
    scale::Float64
    unit::String
    reduction::F
end
PowerSaving(;reduction = maximum) = PowerSaving(1e3, "rel.", reduction)
format_label(m::PowerSaving) = "$(Base.typename(typeof(m.reduction)).name) $(Base.typename(typeof(m)).name) ($(m.unit))"
struct EnergySaving <: AbstractMetric
    scale::Float64
    unit::String
end
EnergySaving() = EnergySaving(1e3, "rel.")
struct Energy <: AbstractMetric
    scale::Float64
    unit::String
end
Energy() = Energy(1e3, "kW")
struct Slowdown <: AbstractMetric
    scale::Float64
    unit::String
end
Slowdown() = Slowdown(1.0, "rel.")
struct Speedup <: AbstractMetric
    scale::Float64
    unit::String
end
Speedup() = Speedup(1.0, "rel.")
struct Runtime <: AbstractMetric
    scale::Float64
    unit::String
end
Runtime() = Runtime(1.0, "s")

function bin_frequencies(freqs, values)
    bins = sort(unique(freqs))
    clusters = [eltype(values)[] for _ in bins]

    for (f, v) in zip(freqs, values)
        i = findfirst(==(f), bins)
        push!(clusters[i], v)
    end

    bins, clusters
end

get_series_for(m::AbstractMetric, partition) = get_series_for(m, cpu_frequency.(partition), partition)

function aggregate_stat(f, samples)
    all = reduce(hcat, samples)
    agg = reduce(hcat, map(f, eachrow(all)))'
    collect(eachcol(agg))
end

function get_series_for(m::Power, freqs, partition)
    raw_perf = last.(perf_timeseries.(partition))
    perf_power = m.reduction.(raw_perf) ./ m.scale
    bmc_power = m.reduction.(bmc_timeseries.(partition)) ./ m.scale


    bins, perf_values = bin_frequencies(freqs, perf_power)
    _, bmc_values = bin_frequencies(freqs, bmc_power)
    (;frequencies = bins, perf = perf_values, bmc = bmc_values)
end

function get_series_for(::Runtime, freqs, partition)
    times = totaltime.(partition)
    bins, time_values = bin_frequencies(freqs, times)
    (;frequencies = bins, time = time_values)
end

function get_series_for(m::PowerSaving, freqs, partition)
    f(row) = inv.(row ./ maximum(row))
    series = get_series_for(Power(m.scale, m.unit, m.reduction), freqs, partition)  
    perf = aggregate_stat(f, series.perf)
    bmc = aggregate_stat(f, series.bmc)
    (;frequencies = series.frequencies, perf = perf, bmc = bmc)
end

function get_series_for(m::EnergySaving, freqs, partition)
    f(row) = inv.(row ./ maximum(row))
    series = get_series_for(Energy(m.scale, m.unit), freqs, partition)  
    perf = aggregate_stat(f, series.perf)
    bmc = aggregate_stat(f, series.bmc)
    (;frequencies = series.frequencies, perf = perf, bmc = bmc)
end

function get_series_for(::Speedup, freqs, partition)
    times = get_series_for(Runtime(), freqs, partition)
    f(row) = inv.(row ./ maximum(row))
    speedup = aggregate_stat(f, times.time)
    (;frequencies = times.frequencies, time = speedup)
end

function get_series_for(::Slowdown, freqs, partition)
    times = get_series_for(Runtime(), freqs, partition)
    f(row) = (row ./ minimum(row))
    speedup = aggregate_stat(f, times.time)
    (;frequencies = times.frequencies, time = speedup)
end

function get_series_for(m::Energy, freqs, partition)
    perf_e = perf_energy.(partition) ./ m.scale
    bmc_e = bmc_energy.(partition) ./ m.scale

    bins, perf_values = bin_frequencies(freqs, perf_e)
    _, bmc_values = bin_frequencies(freqs, bmc_e)
    (;frequencies = bins, perf = perf_values, bmc = bmc_values)
end


abstract type AbstractMeasurement end
struct Perf <: AbstractMeasurement
end
struct BMC <: AbstractMeasurement
end
