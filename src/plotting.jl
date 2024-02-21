
function scaling_plot(when::AbstractMetric, what::AbstractMetric, partition)
    partition_name = partition[1].partition
    benchmark_name = benchmarkname(partition[1])

    color = Makie.wong_colors()
    freqs = cpu_frequency.(partition)
    series = get_series_for(what, freqs, partition)
    time = get_series_for(when, freqs, partition).time

    time_label = format_label(when)
    reading_label = format_label(what)

    fig = Figure(size = (800, 400))
    ax = Axis(fig[2, 1], xlabel = "CPU Frequency (MHz)", ylabel = time_label)
    ax2 = Axis(fig[2, 1], ylabel = reading_label, yaxisposition = :right)
    ax3 = Axis(fig[2, 2], xlabel = time_label, ylabel = reading_label)

    scatter!(
        ax,
        series.frequencies,
        mean.(time),
        color = color[1],
        marker = :x,
        label = "Core time",
    )
    errorbars!(
        ax,
        series.frequencies,
        mean.(time),
        std.(time),
        whiskerwidth = 8,
        color = color[1],
    )

    axislegend(ax)

    scatterlines!(ax2, series.frequencies, mean.(series.perf), color = color[2])
    errorbars!(
        ax2,
        series.frequencies,
        mean.(series.perf),
        std.(series.perf),
        whiskerwidth = 8,
        color = color[2],
    )

    scatterlines!(ax2, series.frequencies, mean.(series.bmc), color = color[3])
    errorbars!(
        ax2,
        series.frequencies,
        mean.(series.bmc),
        std.(series.bmc),
        whiskerwidth = 8,
        color = color[3],
    )

    if when isa Slowdown && what isa PowerSaving
        ablines!(ax3, 0, 1, linestyle = :dash, color = :gray)
    end
    if when isa Speedup && what isa EnergySaving
        ablines!(ax3, 0, 1, linestyle = :dash, color = :gray)
    end

    c = color[2]
    ep = scatterlines!(ax3, mean.(time), mean.(series.perf), color = c)
    errorbars!(ax3, mean.(time), mean.(series.perf), std.(series.perf), color = c)
    errorbars!(ax3, mean.(time), mean.(series.perf), std.(time), direction = :x, color = c)
    c = color[3]
    cp = scatterlines!(ax3, mean.(time), mean.(series.bmc), color = c)
    errorbars!(ax3, mean.(time), mean.(series.bmc), std.(series.bmc), color = c)
    errorbars!(ax3, mean.(time), mean.(series.bmc), std.(time), direction = :x, color = c)

    Legend(
        fig[1, 1:2],
        [ep, cp],
        ["perf pkg + ram", "BMC"],
        "Readout",
        orientation = :horizontal,
        titleposition = :left,
    )

    Label(fig[1, 1:2, Top()], "Partition: $(partition_name)", padding = (0, 600, 5, 0))
    Label(fig[1, 1:2, Top()], "Benchmark: $(benchmark_name)", padding = (500, 0, 5, 0))

    fig
end

function timeseries_plot(partition, what::AbstractMeasurement)
    partition_name = partition[1].partition
    benchmark_name = benchmarkname(partition[1])
    fig = Figure()
    ylabel = "Power (W) [$(Base.typename(typeof(what)).name)]"
    ax = Axis(fig[1, 1], ylabel = ylabel, xlabel = "Time (s)")
    xlims!(ax, 0, 100)

    Label(fig[1, 1, Top()], "Partition: $(partition_name)", padding = (0, 300, 5, 0))
    Label(fig[1, 1, Top()], "Benchmark: $(benchmark_name)", padding = (200, 0, 5, 0))

    data = _reduce_timeseries.(partition, (what,))
    for d in data
        t0 = minimum(d.time)
        lines!(ax, d.time .- t0, d.data)
    end
    fig
end

function _symbol_to_index(partition)
    if partition == :sapphire
        1
    elseif partition == :icelake
        2
    elseif partition == :cclake
        3
    else
        error("Unknown partition $partition")
    end
end

function scaling_plot(
    when::AbstractMetric,
    what::AbstractMetric,
    bi::BenchmarkInfo,
    partition::Symbol,
)
    index = _symbol_to_index(partition)

    time_label = format_label(when)
    reading_label = format_label(what)

    fig = Figure()
    ax = Axis(fig[1, 1], xlabel = time_label, ylabel = reading_label)

    partition_name = "$(partition)"

    Label(fig[1, 1, Top()], "Partition: $(partition_name)", padding = (0, 400, 5, 0))

    color = Makie.wong_colors()
    itt = Iterators.Stateful(Iterators.cycle(color))

    for (name, b) in each_benchmark(bi)
        # seems to be missing
        if name == :hpgmgfv
            continue
        end
        run_infos = filter_clusters(b)[index]
        _plot_scaling!(ax, when, what, run_infos, popfirst!(itt), popfirst!(itt))
    end

    fig
end

function scaling_plot(
    when::TargetMetric,
    what::AbstractMetric,
    bi::BenchmarkInfo,
    partition::Symbol,
)
    index = _symbol_to_index(partition)

    time_label = format_label(when)
    reading_label = format_label(what)

    fig = Figure()
    ax = Axis(fig[1, 1], xlabel = time_label, ylabel = reading_label)

    partition_name = "$(partition)"

    Label(fig[1, 1, Top()], "Partition: $(partition_name)", padding = (0, 400, 5, 0))

    color = Makie.wong_colors()
    itt = Iterators.Stateful(Iterators.cycle(color))

    for (name, b) in each_benchmark(bi)
        # seems to be missing
        if name == :hpgmgfv
            continue
        end
        run_infos = filter_matching(when, filter_clusters(b)[index])
        _plot_scaling!(ax, when.metric, what, run_infos, popfirst!(itt), popfirst!(itt))
    end

    fig
end

function _plot_scaling!(ax, when::AbstractMetric, what::AbstractMetric, partition, c1, c2)
    freqs = cpu_frequency.(partition)
    series = get_series_for(what, freqs, partition)
    time = get_series_for(when, freqs, partition).time

    @show unique(freqs)

    # ep = scatterlines!(ax, mean.(time), mean.(series.perf), color = c1)
    # errorbars!(ax, mean.(time), mean.(series.perf), std.(series.perf), color = c1)
    # errorbars!(ax, mean.(time), mean.(series.perf), std.(time), direction = :x, color = c1)

    cp = scatterlines!(ax, mean.(time), mean.(series.bmc), color = c2, linestyle = :dash)
    errorbars!(ax, mean.(time), mean.(series.bmc), std.(series.bmc), color = c2)
    errorbars!(ax, mean.(time), mean.(series.bmc), std.(time), direction = :x, color = c2)
end

export timeseries_plot, scaling_plot
