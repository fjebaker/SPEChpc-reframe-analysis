_reduce(::AbstractMetric, v::Vector{<:Number}) = v
function _reduce(::AbstractMetric, v::Vector{<:Vector{<:Number}})
    map(v) do x
        mean(x)
    end
end
function _reduce(::AbstractMetric, v::Vector{<:Vector{<:Vector{<:Number}}})
    map(v) do x
        shortest = minimum(length, x)
        mat = reduce(hcat, i[1:shortest] for i in x)
        mean(mat, dims = 2)
    end
end


function scaling_plot!(ax, bv::BinnedValues; kwargs...)
    vs = _reduce(bv.metric, bv.values)
    scatter!(ax, bv.bins, vs; kwargs...)
end

function scaling_plot!(ax, sv::SeriesValues; kwargs...)
    for (time, vals) in zip(sv.times, sv.values)
        lines!(ax, time, vals; kwargs...)
    end
end

function scaling_plot(args...; kwargs...)
    fig = Figure()
    ax = Axis(fig[1, 1])
    scaling_plot!(ax, args...; kwargs...)
    fig
end

export scaling_plot, scaling_plot!


###############################################################################


function _iv_series(when::AbstractMetric, partition)
    ivs = get_iv.(partition)
    time = get_series_for(when, ivs, partition)
    time.bins, mean.(time.time)
end

function _reduce_iv(dat)
    bins = dat[1][1]
    values = reduce(hcat, last.(dat))
    bins, values
end

function _iv_average(when::AbstractMetric, info::BenchmarkInfo)
    data = []
    for (name, bench) in each_benchmark(info)
        # seems to be missing
        if name == :hpgmgfv
            continue
        end
        parts = filter_clusters(bench)
        dat = map(parts) do p
            _iv_series(when, p)
        end
        push!(data, dat)
    end
    data
    sapphire = _reduce_iv([i[1] for i in data])
    icelake = _reduce_iv([i[2] for i in data])
    cclake = _reduce_iv([i[3] for i in data])
    (sapphire, icelake, cclake)
end

MARKER_LOOKUP = Dict(
    :weather => :cross,
    :clvleaf => :xcross,
    :tealeaf => :rect,
    :lbm => :circle,
    :soma => :diamond,
    :pot3d => :utriangle,
)

function _marker_from_name(name)
    get(MARKER_LOOKUP, name, :star5)
end

function _iv_plot!(
    ax,
    when::AbstractMetric,
    partition::Vector{<:AbstractRunInfo};
    color,
    marker,
    target = missing,
)
    ivs = get_iv.(partition)
    time = get_series_for(when, ivs, partition)

    if !ismissing(target)
        hlines!(ax, [target], color = :black, linestyle = :dash)
    end

    y = if when isa Runtime || when isa Slowdown
        time.time
    else
        time.bmc
    end

    scatterlines!(
        ax,
        time.bins,
        mean.(y),
        color = color,
        label = "Core time",
        marker = marker,
        linewidth = 1.5,
        markersize = 10,
    )
    errorbars!(ax, time.bins, mean.(y), std.(y), whiskerwidth = 8, color = color)
end

function iv_average_plot(
    when,
    info::BenchmarkInfo;
    cluster = missing,
    target = missing,
    ylim = nothing,
)
    color = Makie.wong_colors()
    itt = Iterators.Stateful(Iterators.cycle(color))

    time_label = format_label(when)
    xlabel = get_iv_name(info.weather[1])

    fig = Figure(size = (800, 400))
    ax = Axis(fig[1, 1], xlabel = xlabel, ylabel = time_label)


    avgs = _iv_average(when, info)

    if !ismissing(target)
        hlines!(ax, [target], color = :black, linestyle = :dash)
    end

    for (i, avg) in enumerate(avgs)
        y = mean.(eachrow(avg[2]))
        yspread = std.(eachrow(avg[2]))

        scatter!(ax, avg[1], y, color = color[i], marker = :x, label = format_label(when))
        errorbars!(ax, avg[1], y, yspread, whiskerwidth = 8, color = color[i])
    end


    ylims!(ax, nothing, ylim)

    fig
end

function iv_plot(
    when,
    info::BenchmarkInfo;
    cluster = missing,
    ylim = nothing,
    caps = [],
    kwargs...,
)
    color = Makie.wong_colors()
    itt = Iterators.Stateful(Iterators.cycle(color))

    time_label = format_label(when)
    xlabel = get_iv_name(info.weather[1])

    fig = Figure(size = (800, 400))
    ax = Axis(
        fig[1, 1],
        xlabel = xlabel,
        ylabel = time_label,
        xminorticksvisible = true,
        xminorgridvisible = true,
    )

    if length(caps) > 0
        ss = length(caps)
        vlines!(ax, caps, color = color[1:ss], linestyle = :dash)
    end

    for (name, bench) in each_benchmark(info)
        # seems to be missing
        if name == :hpgmgfv
            continue
        end
        sapp, ice, ccl = filter_clusters(bench)
        if !ismissing(cluster)
            choice = (sapp, ice, ccl)[_symbol_to_index(cluster)]
            _iv_plot!(
                ax,
                when,
                choice;
                color = popfirst!(itt),
                marker = _marker_from_name(name),
                kwargs...,
            )
        else
            _iv_plot!(
                ax,
                when,
                sapp;
                color = color[1],
                marker = _marker_from_name(name),
                kwargs...,
            )
            _iv_plot!(
                ax,
                when,
                ice;
                color = color[2],
                marker = _marker_from_name(name),
                kwargs...,
            )
            _iv_plot!(
                ax,
                when,
                ccl;
                color = color[3],
                marker = _marker_from_name(name),
                kwargs...,
            )
        end
    end

    benchmark_names = ["$(name)" for (name, _) in each_benchmark(info)]
    benchmark_elements = [
        MarkerElement(color = :black, marker = _marker_from_name(name)) for
        (name, _) in each_benchmark(info)
    ]

    sapphire_elem =
        [LineElement(color = color[1]), MarkerElement(color = color[1], marker = '●')]
    icelake_elem =
        [LineElement(color = color[2]), MarkerElement(color = color[2], marker = '●')]
    cclake_elem =
        [LineElement(color = color[3]), MarkerElement(color = color[3], marker = '●')]

    Legend(
        fig[1, 2],
        [sapphire_elem, icelake_elem, cclake_elem, benchmark_elements...],
        ["sapphire", "icelake", "cclake", benchmark_names...],
    )

    ylims!(ax, nothing, ylim)
    fig
end




function scaling_plot(when::AbstractMetric, what::AbstractMetric, partition)
    partition_name = partition[1].partition
    benchmark_name = benchmarkname(partition[1])

    color = Makie.wong_colors()
    ivs = get_iv.(partition)
    series = get_series_for(what, ivs, partition)
    time = get_series_for(when, ivs, partition).time

    time_label = format_label(when)
    reading_label = format_label(what)

    fig = Figure(size = (800, 400))

    xlabel = get_iv_name(first(partition))
    ax = Axis(fig[2, 1], xlabel = xlabel, ylabel = time_label)
    ax2 = Axis(fig[2, 1], ylabel = reading_label, yaxisposition = :right)
    ax3 = Axis(fig[2, 2], xlabel = time_label, ylabel = reading_label)

    scatter!(
        ax,
        series.bins,
        mean.(time),
        color = color[1],
        marker = :x,
        label = "Core time",
    )
    errorbars!(ax, series.bins, mean.(time), std.(time), whiskerwidth = 8, color = color[1])

    axislegend(ax)

    scatterlines!(ax2, series.bins, mean.(series.perf), color = color[2])
    errorbars!(
        ax2,
        series.bins,
        mean.(series.perf),
        std.(series.perf),
        whiskerwidth = 8,
        color = color[2],
    )

    scatterlines!(ax2, series.bins, mean.(series.bmc), color = color[3])
    errorbars!(
        ax2,
        series.bins,
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
    ;
    kwargs...,
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
        _plot_scaling!(ax, when, what, run_infos, popfirst!(itt), popfirst!(itt); kwargs...)
    end

    fig
end

function scaling_plot(
    when::TargetMetric,
    what::AbstractMetric,
    bi::BenchmarkInfo,
    partition::Symbol;
    kwargs...,
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
        _plot_scaling!(
            ax,
            when.metric,
            what,
            run_infos,
            popfirst!(itt),
            popfirst!(itt);
            kwargs...,
        )
    end

    fig
end

function scaling_plot(
    _when::Union{<:TargetMetric,<:AbstractMetric},
    what::AbstractMetric,
    bi::BenchmarkInfo,
    ;
    perf = true,
    bmc = true,
)
    when = if _when isa TargetMetric
        _when.metric
    else
        _when
    end

    time_label = format_label(when)
    reading_label = format_label(what)

    filt(part) =
        if _when isa TargetMetric
            filter_matching(_when, part)
        else
            part
        end

    fig = Figure()
    ax = Axis(fig[1, 1], xlabel = time_label, ylabel = reading_label)

    color = Makie.wong_colors()
    itt = Iterators.Stateful(Iterators.cycle(color))

    sapphire_color = popfirst!(itt)
    icelake_color = popfirst!(itt)
    cclake_color = popfirst!(itt)

    for (name, b) in each_benchmark(bi)
        # seems to be missing
        if name == :hpgmgfv
            continue
        end
        sapphire, icelake, cclake = filter_clusters(b)
        _plot_scaling!(
            ax,
            when,
            what,
            filt(sapphire),
            sapphire_color,
            sapphire_color;
            perf = perf,
            bmc = bmc,
        )
        _plot_scaling!(
            ax,
            when,
            what,
            filt(icelake),
            icelake_color,
            icelake_color;
            perf = perf,
            bmc = bmc,
        )
        _plot_scaling!(
            ax,
            when,
            what,
            filt(cclake),
            cclake_color,
            cclake_color;
            perf = perf,
            bmc = bmc,
        )
    end

    sapphire_elem = [
        LineElement(color = sapphire_color),
        MarkerElement(color = sapphire_color, marker = '●'),
    ]
    icelake_elem = [
        LineElement(color = icelake_color),
        MarkerElement(color = icelake_color, marker = '●'),
    ]
    cclake_elem = [
        LineElement(color = cclake_color),
        MarkerElement(color = cclake_color, marker = '●'),
    ]

    Legend(
        fig[1, 2],
        [sapphire_elem, icelake_elem, cclake_elem],
        ["sapphire", "icelake", "cclake"],
    )

    fig
end

function _plot_scaling!(
    ax,
    when::AbstractMetric,
    what::AbstractMetric,
    partition,
    c1,
    c2;
    perf = true,
    bmc = true,
)
    ivs = get_iv.(partition)
    series = get_series_for(what, ivs, partition)
    time = get_series_for(when, ivs, partition).time

    if perf
        ep = scatterlines!(ax, mean.(time), mean.(series.perf), color = c1)
        errorbars!(ax, mean.(time), mean.(series.perf), std.(series.perf), color = c1)
        errorbars!(
            ax,
            mean.(time),
            mean.(series.perf),
            std.(time),
            direction = :x,
            color = c1,
        )
    end

    if bmc
        cp =
            scatterlines!(ax, mean.(time), mean.(series.bmc), color = c2, linestyle = :dash)
        errorbars!(ax, mean.(time), mean.(series.bmc), std.(series.bmc), color = c2)
        errorbars!(
            ax,
            mean.(time),
            mean.(series.bmc),
            std.(time),
            direction = :x,
            color = c2,
        )
    end
end

export timeseries_plot, scaling_plot, iv_plot, iv_average_plot
