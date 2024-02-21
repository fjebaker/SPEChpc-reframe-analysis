using Analysis
using JSON

sources = [
    "./datasets/all.all-weather.all-freq.json",
    "./datasets/all.weather_t.all-freqs.repeat4.bad_cclake.json",
    "./datasets/all.all-weather.all-freq.json",
    "./datasets/sapphire+icelake.all-weather_t-lbm_t.all-freqs.json",
    "./datasets/cclake.weather_t.all-freqs.repeat4.json",
]

bis = [parse_data_json(JSON.parsefile(s)) for s in sources]

bi = reduce(∪, bis)
bi = drop_first_seconds(bi, 100)

sapphire, icelake, cclake = filter_clusters(bi.weather)

# timeseries_plot(sapphire, BMC())
# timeseries_plot(sapphire, Perf())

# timeseries_plot(icelake, BMC())
# timeseries_plot(icelake, Perf())

# timeseries_plot(cclake, BMC())
# timeseries_plot(cclake, Perf())

fig = scaling_plot(Slowdown(), Power(; reduction = median), icelake)
# Makie.save("power.slowdown.sapphire.weather_t.png", fig)
fig = scaling_plot(Speedup(), EnergySaving(), sapphire)
# Makie.save("energy.speedup.sapphire.weather_t.png", fig)

scaling_plot(Slowdown(), PowerSaving(; reduction = median), icelake)
scaling_plot(Speedup(), EnergySaving(), icelake)

scaling_plot(Slowdown(), PowerSaving(; reduction = median), cclake)
scaling_plot(Speedup(), EnergySaving(), cclake)

scaling_plot(Runtime(), Power(), sapphire)
scaling_plot(Runtime(), Power(), icelake)
scaling_plot(Runtime(), Power(), cclake)

scaling_plot(Runtime(), Energy(), sapphire)
scaling_plot(Runtime(), Energy(), icelake)
scaling_plot(Runtime(), Energy(), cclake)

