function _reduce_timeseries(r::RunInfo, ::BMC)
    data = get_all_timeseries("BMC", r) |> only
    (;time = data[1], data = data[2])
end
function _reduce_timeseries(r::RunInfo, ::Perf)
    time, data = perf_timeseries(r)
    (;time = time, data = data)
end