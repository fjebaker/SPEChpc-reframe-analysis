abstract type AbstractRunInfo end

get_independent_variable(r::AbstractRunInfo) = error("Undefined for $(typeof(r))")
get_iv(r::AbstractRunInfo) = get_independent_variable(r)

get_iv_name(::Type{<:AbstractRunInfo}) = error("Undefined for $(typeof(r))")
get_iv_name(::T) where {T<:AbstractRunInfo} = get_iv_name(T)

iv_domain(rs::Vector{<:AbstractRunInfo}) = sort(collect(Set(map(get_iv, rs))))

function get_with_iv(rs::Vector{<:AbstractRunInfo}, iv)
    selection = filter(i -> get_iv(iv) ≈ iv, rs)
    if length(selection) == 0
        return nothing
    end
    selection
end


Base.show(io::IO, ::MIME"text/plain", r::AbstractRunInfo) = Base.show(io, r)

function get_all_metric(substr, r::AbstractRunInfo)
    selection = filter(i -> occursin(substr, i), collect(keys(r.metrics)))
    map(k -> r.metrics[k], selection)
end

function get_metric(key, r::AbstractRunInfo)
    selection = filter(i -> occursin(key, i), keys(r.metrics)) |> only
    r.metrics[selection]
end

function get_all_timeseries(substr, r::AbstractRunInfo)
    selection = filter(i -> occursin(substr, i), collect(keys(r.time_series)))
    map(k -> r.time_series[k], selection)
end

function get_timeseries(key, r::AbstractRunInfo)
    selection = filter(i -> occursin(key, i), keys(r.time_series)) |> only
    r.time_series[selection]
end

runtime(r::AbstractRunInfo) = Second(r.end_time - r.start_time).value
totaltime(r::AbstractRunInfo) = get_metric("Total time", r)
coretime(r::AbstractRunInfo) = get_metric("Core time", r)
bmc_energy(r::AbstractRunInfo) = get_metric("BMC", r)
function bmc_timeseries(r::AbstractRunInfo)
    get_timeseries("BMC", r)[2]
end

benchmarkname(r::AbstractRunInfo) = lowercase(first(split(r.name)))

function perf_timeseries(r::AbstractRunInfo)
    pkgs = get_all_timeseries("energy-pkg", r)
    rams = get_all_timeseries("energy-ram", r)
    pkg_mat = reduce(hcat, [i[2] for i in pkgs])
    ram_mat = try
        reduce(hcat, [i[2] for i in rams])
    catch
        zeros(eltype(pkg_mat), size(pkg_mat))
    end
    dt = diff(pkgs[1][1])
    readings = sum(pkg_mat, dims = 2) .+ sum(ram_mat, dims = 2)
    (pkgs[1][1][2:end-2], readings[2:end-2] ./ dt[2:end-1])
end

function perf_energy(r::AbstractRunInfo)
    pkgs = get_all_metric("energy-pkg", r)
    rams = get_all_metric("energy-ram", r)
    (sum(pkgs) + sum(rams))
end

function filter_clusters(rs::Vector{<:AbstractRunInfo})
    sapphires = filter_nodes(rs, "sapphire")
    icelakes = filter_nodes(rs, "icelake")
    cclakes = filter_nodes(rs, "cclake")

    [sapphires, icelakes, cclakes]
end

# some sorting utilities

is_build_step(r) = occursin("build", r["display_name"])
is_success(r) = r["result"] == "success"

is_benchmark(r::AbstractRunInfo, name) = contains(lowercase(r.name), name)
filter_nodes(rs::Vector{<:AbstractRunInfo}, partition) =
    filter(i -> i.partition == partition, rs)


struct FrequencyRunInfo <: AbstractRunInfo
    name::String
    partition::String
    cpu_frequency::Float64
    start_time::DateTime
    end_time::DateTime
    node_name::String
    time_series::Dict{String,Vector{Vector{Float64}}}
    metrics::Dict{String,Float64}
end

function FrequencyRunInfo(testcase::AbstractDict)
    FrequencyRunInfo(
        testcase["display_name"],
        split(testcase["system"], ':')[2],
        convert(Float64, testcase["check_vars"]["cpu_frequency"]),
        DateTime(testcase["check_vars"]["job_start_time"], DATE_FORMAT),
        DateTime(testcase["check_vars"]["job_end_time"], DATE_FORMAT),
        only(testcase["nodelist"]),
        testcase["check_vars"]["time_series"],
        Dict(i["name"] => i["value"] for i in testcase["perfvars"]),
    )
end

get_independent_variable(r::FrequencyRunInfo) = r.cpu_frequency
get_iv_name(::Type{<:FrequencyRunInfo}) = "CPU Frequency (MHz)"

Base.show(io::IO, r::FrequencyRunInfo) =
    print(io, "FrequencyRunInfo{$(r.partition)@$(format_frequency(r.cpu_frequency))}")

struct PowercapRunInfo <: AbstractRunInfo
    name::String
    partition::String
    powercap::Float64
    start_time::DateTime
    end_time::DateTime
    node_name::String
    time_series::Dict{String,Vector{Vector{Float64}}}
    metrics::Dict{String,Float64}
end

function PowercapRunInfo(testcase::AbstractDict)
    partition = split(testcase["system"], ':')[2]
    PowercapRunInfo(
        testcase["display_name"],
        partition,
        convert(Float64, testcase["check_vars"]["powercap_values"][partition]),
        DateTime(testcase["check_vars"]["job_start_time"], DATE_FORMAT),
        DateTime(testcase["check_vars"]["job_end_time"], DATE_FORMAT),
        only(testcase["nodelist"]),
        testcase["check_vars"]["time_series"],
        Dict(i["name"] => i["value"] for i in testcase["perfvars"]),
    )
end

get_independent_variable(r::PowercapRunInfo) = r.powercap
get_iv_name(::Type{<:PowercapRunInfo}) = "Powercap (W)"

Base.show(io::IO, r::PowercapRunInfo) =
    print(io, "PowercapRunInfo{$(r.partition)@$(r.powercap)}")


export FrequencyRunInfo, PowercapRunInfo, filter_clusters
