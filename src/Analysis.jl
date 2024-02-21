module Analysis

using Makie
using CairoMakie
using JSON
using Dates
using Printf
using Statistics
using NumericalIntegration

DATE_FORMAT = DateFormat("y-m-dTH:M:S")

format_frequency(freq) = Printf.@sprintf "%.0f MHz" freq

include("metrics.jl")
include("run-info.jl")
include("benchmark-info.jl")
include("utils.jl")
include("plotting.jl")
include("optimization.jl")

end # module analysis
