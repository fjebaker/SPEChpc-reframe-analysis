struct RunInfo
    name::String
    partition::String
    cpu_frequency::Float64
    start_time::DateTime
    end_time::DateTime
    node_name::String
    time_series::Dict{String,Vector{Vector{Float64}}}
    metrics::Dict{String,Float64}
end

Base.show(io::IO, ::MIME"text/plain", r::RunInfo) = Base.show(io, r)
Base.show(io::IO, r::RunInfo) =
    print(io, "RunInfo{$(r.partition)@$(format_frequency(r.cpu_frequency))}")

function RunInfo(testcase::AbstractDict)
    RunInfo(
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

function get_all_metric(substr, r::RunInfo)
    selection = filter(i -> occursin(substr, i), collect(keys(r.metrics)))
    map(k -> r.metrics[k], selection)
end

function get_metric(key, r::RunInfo)
    selection = filter(i -> occursin(key, i), keys(r.metrics)) |> only
    r.metrics[selection]
end

function get_all_timeseries(substr, r::RunInfo)
    selection = filter(i -> occursin(substr, i), collect(keys(r.time_series)))
    map(k -> r.time_series[k], selection)
end

function get_timeseries(key, r::RunInfo)
    selection = filter(i -> occursin(key, i), keys(r.time_series)) |> only
    r.time_series[selection]
end

runtime(r::RunInfo) = Second(r.end_time - r.start_time).value
totaltime(r::RunInfo) = get_metric("Total time", r)
coretime(r::RunInfo) = get_metric("Core time", r)
cpu_frequency(r::RunInfo) = r.cpu_frequency
bmc_energy(r::RunInfo) = get_metric("BMC", r)
function bmc_timeseries(r::RunInfo)
    get_timeseries("BMC", r)[2]
end

benchmarkname(r::RunInfo) = lowercase(first(split(r.name)))

function perf_timeseries(r::RunInfo)
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

function perf_energy(r::RunInfo)
    pkgs = get_all_metric("energy-pkg", r)
    rams = get_all_metric("energy-ram", r)
    (sum(pkgs) + sum(rams))
end

frequency_domain(rs::Vector{RunInfo}) = sort(collect(Set(i.cpu_frequency for i in rs)))

function get_frequency(rs::Vector{RunInfo}, f)
    selection = filter(i -> i.cpu_frequency ≈ f, rs)
    if length(selection) == 0
        return nothing
    end
    selection
end

function filter_clusters(rs::Vector{RunInfo})
    sapphires = filter_nodes(rs, "sapphire")
    icelakes = filter_nodes(rs, "icelake")
    cclakes = filter_nodes(rs, "cclake")

    [sapphires, icelakes, cclakes]
end

# some sorting utilities

is_build_step(r) = occursin("build", r["display_name"])
is_success(r) = r["result"] == "success"

is_benchmark(r::RunInfo, name) = contains(lowercase(r.name), name)
filter_nodes(rs::Vector{RunInfo}, partition) = filter(i -> i.partition == partition, rs)


export RunInfo, filter_clusters
