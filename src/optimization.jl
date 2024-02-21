function find_optimal(target::TargetMetric, partition::Vector{FrequencyRunInfo})
    freqs = cpu_frequency.(partition)
    unique_freqs, target_series = get_series_for(target.metric, freqs, partition)
    series = mean.(target_series)
    I = target.target_function.(series)

    unique_freqs[I], series[I]
end

function filter_matching(target::TargetMetric, partition::Vector{FrequencyRunInfo})
    freqs, _ = find_optimal(target, partition)
    filter(i -> any(i.cpu_frequency .≈ freqs), partition)
end

export find_optimal, filter_matching
