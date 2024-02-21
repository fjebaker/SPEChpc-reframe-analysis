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


scaling_plot(Slowdown() < 1.35, Power(; reduction = median), bi, :sapphire)

optimal = filter_matching(Slowdown() < 1.15, sapphire)
scaling_plot(Slowdown(), PowerSaving(; reduction = median), optimal)
