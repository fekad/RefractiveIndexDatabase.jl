module RefractiveIndexDatabase

using YAML
using HTTP:request
using DelimitedFiles:readdlm

using Memoize
using Unitful: @u_str, uparse, uconvert, ustrip, AbstractQuantity
import Base: show

using Dierckx:Spline1D

# using Pkg.Artifacts


abstract type Formula end
abstract type RefractiveIndexInfo end


struct MaterialCatalog
    shelf::String
    book::String
    page::String
end

struct MaterialEntry
    name::String
    path::String
end

const DB_ROOT = joinpath("refractiveindex.info-database", "database")
const DB = Dict{MaterialCatalog,MaterialEntry}()

export get_material
include("database.jl")

include("formulas.jl")

export load_file, load_url
include("interfaces.jl")

struct Metadata
    reference::String
    comment::String
    specs::Dict{Any,Any}
end


struct RealFormula <: RefractiveIndexInfo
    meta::Metadata
    n::Formula
end


struct ComplexFormula <: RefractiveIndexInfo
    meta::Metadata
    n::Formula
    k::Tabulated
end


struct RealTabulated <: RefractiveIndexInfo
    metadata::Metadata
    λ::Vector{Float64}
    n::Vector{Float64}
    _n_itp::Spline1D

    function RealTabulated(metadata, λ, n)
        @assert length(λ) == length(n)
        _n_itp = Spline1D(λ, n, bc="error") # error on ectrapolation
        return new(metadata, λ, n, _n_itp)
    end
end

struct ComplexTabulated <: RefractiveIndexInfo
    metadata::Metadata
    λ::Vector{Float64}
    n::Vector{Float64}
    k::Vector{Float64}
    _n_itp::Spline1D
    _k_itp::Spline1D

    function ComplexTabulated(metadata, λ, n, k)
        @assert length(λ) == length(n) == length(k)

        _n_itp = Spline1D(λ, n, bc="error") # error on ectrapolation
        _k_itp = Spline1D(λ, n, bc="error") # error on ectrapolation
        return new(metadata, λ, n, k, _n_itp, _k_itp)
    end
end

(m::RealFormula)(λ::Float64) = m.n(λ)
(m::ComplexFormula)(λ::Float64) = m.n(λ) + m.k(λ)

(m::RealTabulated)(λ::Float64) = m._n_itp(λ)
(m::ComplexTabulated)(λ::Float64) = m._n_itp(λ) + m._k_itp(λ)


@memoize _dim_to_micron(dim) = ustrip(uconvert(u"μm", 1.0uparse(dim)))
(m::RefractiveIndexInfo)(λ, dim::String) = m(λ*_dim_to_micron(dim))
(m::RefractiveIndexInfo)(λ::AbstractQuantity) = m(Float64(ustrip(uconvert(u"μm", λ))))


show(io::IO, ::MIME"text/plain", m::RefractiveIndexInfo) = show(io, typeof(m))


# (m::RefractiveIndexInfo{T})(λ::Float64) where {T <: Tabulated}= m.dispersion.n(λ)
# RefractiveIndex{Formula, Tabulated}
# RefractiveIndex{Tabulated, Tabulated}


end # module