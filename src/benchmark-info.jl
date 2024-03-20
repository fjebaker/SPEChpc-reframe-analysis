
struct BenchmarkInfo{T<:AbstractRunInfo}
    clvleaf::Vector{T}
    # hpgmgfv::Vector{T}
    lbm::Vector{T}
    pot3d::Vector{T}
    soma::Vector{T}
    tealeaf::Vector{T}
    weather::Vector{T}
end

function Base.show(io::IO, ::MIME"text/plain", r::BenchmarkInfo)
    println(io, "BenchmarkInfo")
    for (s, bmark) in each_benchmark(r)
        if length(bmark) > 0
            lims =    extrema(get_iv.(bmark))
            unit = get_iv_name(bmark[1])
            println(io, "  . $s : $(length(bmark)) [$(lims[1]) - $(lims[2]) $unit]")
        else
            println(io, "  . $s : NO DATA")
        end
    end
end

function split_partitions(bi::BenchmarkInfo)
    splits = map(each_benchmark(bi)) do x
        _, runs = x
        split_partitions(runs)
    end
    args = map(each_species()) do index
        runs = map(splits) do s
            getfield(s, index)
        end
        BenchmarkInfo(runs...)
    end
    PartitionSplit(args...)
end

function num_benchmarks(bi::BenchmarkInfo)
    sum(i -> length(i[2]), each_benchmark(bi))
end

# permit broadcasting
Base.broadcastable(b::BenchmarkInfo) = Ref(b)

function benchmark_symbols(::T) where {T<:BenchmarkInfo}
    (fieldnames(T)...,)
end

function each_benchmark(bi::BenchmarkInfo{T}) where {T}
    N::Int = length(fieldnames(BenchmarkInfo{T}))
    generator = ((f, getfield(bi, f)) for f in fieldnames(BenchmarkInfo{T}))
    res::NTuple{N,Tuple{Symbol,Vector{T}}} = (generator...,)
    res
end

get_iv_name(bi::BenchmarkInfo{T}) where {T} = get_iv_name(T)

function join_benchmark_info(b1::BenchmarkInfo, b2::BenchmarkInfo)
    BenchmarkInfo(
        vcat(b1.clvleaf, b2.clvleaf),
        # vcat(b1.hpgmgfv, b2.hpgmgfv),
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

function parse_data_json(path::AbstractString; as::Type = FrequencyRunInfo)
    data = JSON.parsefile(path)
    all_runs = data["runs"][1]["testcases"]

    # get all the actual runs, and those not skipped or failed
    runs = filter(i -> !is_build_step(i) && is_success(i), all_runs)
    infos = sort(map(as, runs), by = i -> i.node_name)

    clvleaf_t = filter(i -> is_benchmark(i, "clvleaf_t"), infos)
    # hpgmgfv_t = filter(i -> is_benchmark(i, "hpgmgfv_t"), infos)
    lbm_t = filter(i -> is_benchmark(i, "lbm_t"), infos)
    pot3d_t = filter(i -> is_benchmark(i, "pot3d_t"), infos)
    soma_t = filter(i -> is_benchmark(i, "soma_t"), infos)
    tealeaf_t = filter(i -> is_benchmark(i, "tealeaf_t"), infos)
    weather_t = filter(i -> is_benchmark(i, "weather_t"), infos)

    BenchmarkInfo(
        clvleaf_t,
        # hpgmgfv_t,
        lbm_t,
        pot3d_t,
        soma_t,
        tealeaf_t,
        weather_t,
    )
end

export parse_data_json, BenchmarkInfo, split_partitions
