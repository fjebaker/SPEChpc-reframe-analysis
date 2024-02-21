function _reduce_timeseries(r::AbstractRunInfo, ::BMC)
    data = get_all_timeseries("BMC", r) |> only
    (; time = data[1], data = data[2])
end

function _reduce_timeseries(r::AbstractRunInfo, ::Perf)
    time, data = perf_timeseries(r)
    (; time = time, data = data)
end

function drop_first_seconds(ri::AbstractRunInfo, s)
    # adjust time series for each one
    for (k, v) in ri.time_series
        time, data = v
        I = (time .- time[1]) .>= s
        ri.time_series[k] = [time[I], data[I]]
    end
    # adjust the integrated metrics
    for (k, v) in ri.time_series
        if k in keys(ri.metrics)
            if occursin("BMC", k)
                # reintegrate using trapezoidal method
                ri.metrics[k] = integrate(v[1], v[2])
            elseif occursin("/power/", k)
                ri.metrics[k] = sum(v[2])
            else
                error("Unknown key: $k")
            end
        end
    end
    ri
end

function drop_first_seconds(bi::BenchmarkInfo, s)
    trimmed = map(fieldnames(typeof(bi))) do field_name
        run_infos = getfield(bi, field_name)
        map(i -> drop_first_seconds(i, s), run_infos)
    end
    BenchmarkInfo(trimmed...)
end

export drop_first_seconds
