
function _metric_with_iv(metric::AbstractMetric, infos::Vector{<:AbstractRunInfo})

    ivs = get_iv.(infos)
    series = get_series_for(metric, ivs, partition)
end

function _iv_series(when::AbstractMetric, partition) end
