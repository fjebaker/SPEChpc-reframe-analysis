using Analysis

sources = [
    "./datasets/all.all-weather.all-freq.json",
    "./datasets/all.weather_t.all-freqs.repeat4.bad_cclake.json",
    "./datasets/all.all-weather.all-freq.json",
    "./datasets/sapphire+icelake.all-weather_t-lbm_t.all-freqs.json",
    "./datasets/cclake.weather_t.all-freqs.repeat4.json",
]

bis = [parse_data_json(JSON.parsefile(s)) for s in sources]

bi = reduce(∪, bis)

sapphire, icelake, cclake = filter_clusters(bi.weather)

timeseries_plot(sapphire, BMC())
timeseries_plot(sapphire, Perf())

timeseries_plot(icelake, BMC())
timeseries_plot(icelake, Perf())

timeseries_plot(cclake, BMC())
timeseries_plot(cclake, Perf())

fig = scaling_plot(Slowdown(), PowerSaving(;reduction=median), sapphire)
# Makie.save("power.slowdown.sapphire.weather_t.png", fig)
fig = scaling_plot(Speedup(), EnergySaving(), sapphire)
# Makie.save("energy.speedup.sapphire.weather_t.png", fig)

scaling_plot(Slowdown(), PowerSaving(;reduction = median), icelake)
scaling_plot(Speedup(), EnergySaving(), icelake)

scaling_plot(Slowdown(), PowerSaving(;reduction = median), cclake)
scaling_plot(Speedup(), EnergySaving(), cclake)

scaling_plot(Runtime(), Power(), sapphire)
scaling_plot(Runtime(), Power(), icelake)
scaling_plot(Runtime(), Power(), cclake)

scaling_plot(Runtime(), Energy(), sapphire)
scaling_plot(Runtime(), Energy(), icelake)
scaling_plot(Runtime(), Energy(), cclake)

nothing
















partition = cclake

begin
end

begin
    Makie.save("scaling.$(partition_name).$(benchmark_name).png", fig)
    fig
end




# histogram showing the energy usage of each cluster

function plot_energy_histogram!(ax, rs::Vector{RunInfo})
    num_runs = length(rs)

    bmc_values = bmc_energy.(rs) ./ 1e3
    perf_values = perf_energy.(rs) ./ 1e3

    b1 = barplot!(ax, 1:num_runs, bmc_values)
    b2 = barplot!(ax, 1:num_runs, perf_values, gap = 0.4)

    (b1, b2)
end

function energy_histogram(rs::Vector{RunInfo})
    infos = sort(rs, by = i -> i.cpu_frequency)

    colors = Makie.wong_colors()

    freq_range = frequency_domain(infos)

    fig = Figure(size=(700, 550))

    ax = Axis(
        fig[1,1],
        # xticks = (1:num_runs, map(i -> i.node_name, infos)),
        xlabel = "Node",
        ylabel = "kJ",
        xgridvisible = false,
    )

    clusters = filter_clusters(infos)

    groups = [
        filter(!isnothing, reduce(hcat, get_frequency.(clusters, f))) for f in freq_range
    ]

    for (i, g) in enumerate(groups)
        @show g
        bmc_values = bmc_energy.(g) ./ 1e3
        perf_values = perf_energy.(g) ./ 1e3
        cols = colors[[1, 2, 3]][1:length(g)]
        cols2 = colors[[5, 4, 6]][1:length(g)]
        barplot!(ax, (1:length(g)) .+ 4i, bmc_values, color = cols)
        barplot!(ax, (1:length(g)) .+ 4i, perf_values, gap = 0.5, color = cols2)
    end

    # Legend(fig[1, 1], [b1, b2], ["BMC", "perf pkg + ram"], "Energy reading",
    #     orientation = :horizontal
    # )

    # for (i, info) in enumerate(infos)
    #     text!(ax, i - 0.3, 10 + bmc_values[i], text = format_frequency(info.cpu_frequency))
    # end

    Label(fig[1, 1, Top()], "Benchmark: 535.weather_t",
    padding = (0, 300, 5, 0),)

    fig
end


energy_histogram(bi.weather)

begin

    # Makie.save("test-histogram.png", fig)
end


core_times = map(infos) do info
    get_metric("Core time", info.metrics)
end

runtimes_times = map(infos) do info
    calc_runtime(info)
end


function plot_time_energy!(ax, infos; kwargs...)
    time = map(infos) do info
        # get_metric("Core time", info.metrics)
        calc_runtime(info)
    end

    perf_totals = map(infos) do info
        pkgs = get_all_metric("energy-pkg", info.metrics)
        rams = get_all_metric("energy-ram", info.metrics)
        (sum(pkgs) + sum(rams)) ./ 1e3
    end

    I = sortperm(time)
    @views scatterlines!(ax, time[I], perf_totals[I]; kwargs...)
end

function plot_freq_time!(ax, infos; kwargs...)
    # time = map(infos) do info
    #     # get_metric("Core time", info.metrics)
    #     calc_runtime(info)
    # end
    time = map(infos) do info
        pkgs = get_all_metric("energy-pkg", info.metrics)
        rams = get_all_metric("energy-ram", info.metrics)
        (sum(pkgs) + sum(rams)) ./ 1e3
    end
    freqs = map(i -> i.cpu_frequency, infos)
    I = sortperm(freqs)
    @views scatterlines!(ax, freqs[I], time[I]; kwargs...)
end

sapphires = filter(i -> i.partition == "sapphire", infos)
cascades = filter(i -> i.partition == "cclake", infos)
icelakes = filter(i -> i.partition == "icelake", infos)

begin
    fig = Figure(size=(700, 550))

    ax = Axis(
        fig[1,1],
        # xlabel = "Core time (SPEChpc)",
        # ylabel = "Energy"
    )

    plot_freq_time!(ax, sapphires)
    plot_freq_time!(ax, cascades)
    plot_freq_time!(ax, icelakes)

    fig
end

begin
    fig = Figure(size=(700, 550))

    ax = Axis(
        fig[1,1],
        xlabel = "Core time (SPEChpc)",
        ylabel = "Run Time (sacct)"
    )

    plot!(ax, core_times, perf_totals)
    plot!(ax, core_times, bmc_values)
    # abline!(ax, 0, 1)

    fig
end
