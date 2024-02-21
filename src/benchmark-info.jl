struct BenchmarkInfo{T}
    clvleaf::Vector{T}
    hpgmgfv::Vector{T}
    lbm::Vector{T}
    pot3d::Vector{T}
    soma::Vector{T}
    tealeaf::Vector{T}
    weather::Vector{T}
end

Base.length(::BenchmarkInfo) = 1
Base.iterate(m::BenchmarkInfo) = (m, nothing)
Base.iterate(::BenchmarkInfo, ::Nothing) = nothing

each_benchmark(bi::BenchmarkInfo) =
    ((f, getfield(bi, f)) for f in fieldnames(BenchmarkInfo))

function join_benchmark_info(b1::BenchmarkInfo, b2::BenchmarkInfo)
    BenchmarkInfo(
        vcat(b1.clvleaf, b2.clvleaf),
        vcat(b1.hpgmgfv, b2.hpgmgfv),
        vcat(b1.lbm, b2.lbm),
        vcat(b1.pot3d, b2.pot3d),
        vcat(b1.soma, b2.soma),
        vcat(b1.tealeaf, b2.tealeaf),
        vcat(b1.weather, b2.weather),
    )
end

function Base.:∪(b1::BenchmarkInfo, b2::BenchmarkInfo)
    join_benchmark_info(b1, b2)
end

function parse_data_json(data; as::Type = FrequencyRunInfo)
    all_runs = data["runs"][1]["testcases"]

    # get all the actual runs, and those not skipped or failed
    runs = filter(i -> !is_build_step(i) && is_success(i), all_runs)
    infos = sort(map(as, runs), by = i -> i.node_name)

    clvleaf_t = filter(i -> is_benchmark(i, "clvleaf_t"), infos)
    hpgmgfv_t = filter(i -> is_benchmark(i, "hpgmgfv_t"), infos)
    lbm_t = filter(i -> is_benchmark(i, "lbm_t"), infos)
    pot3d_t = filter(i -> is_benchmark(i, "pot3d_t"), infos)
    soma_t = filter(i -> is_benchmark(i, "soma_t"), infos)
    tealeaf_t = filter(i -> is_benchmark(i, "tealeaf_t"), infos)
    weather_t = filter(i -> is_benchmark(i, "weather_t"), infos)

    BenchmarkInfo(clvleaf_t, hpgmgfv_t, lbm_t, pot3d_t, soma_t, tealeaf_t, weather_t)
end


export parse_data_json, BenchmarkInfo
