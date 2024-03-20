using Analysis

datafile = "./datasets/all.all-weather.all-freq.json"
all_info = parse_data_json(datafile)

# split into the different partitions
parts = split_partitions(all_info)

# plot the independent variable (frequency) against a metric of choice
fig, ax = scaling_plot(Power(measurement=Perf()), parts.icelake)
fig

# to plot specific variables, use the overloaded dispatch
fig, ax = scaling_plot(Time(), Power(measurement=Perf()), parts.icelake)
fig