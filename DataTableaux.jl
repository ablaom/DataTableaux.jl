module DataTableaux

export Small, IntegerSet, DataTableau, row, head, countmap

# hoping I can dump this:
# export push!, in, round, show, showall, Float64

# currently commenting out next because of anticipated confilicts with Koala
# export fit!, transform, fit_transform!, inverse_transform, FrameToTableauScheme

using DataFrames
# using ADBUtilities

# to be extended:
import StatsBase.countmap
import DataFrames.head
import Base: getindex, show, showall, convert, length
import Base: size, start, next, done, issparse, ndims, copy
import Base: in, push!, Float64, round


## Constants:
const Small=UInt8
const Big=UInt64
const SMALL_MAX = Small(52) 
const BIG_MAX = Big(2^(Int(SMALL_MAX) + 1) - 1)
const TWO = Big(2)
const ZERO = Big(0)
const ONE = Small(1)
const srcdir = dirname(@__FILE__)


## Helpers:

"""Load a well-known public regression dataset."""
function load_boston()
    df = CSV.read(joinpath(srcdir, "data", "Boston.csv"))
    features = filter(names(df)) do f
        f != :MedV
    end
    X = df[features] 
    y = df[:MedV]
    return X, y 
end

function second_less_than(pair1, pair2)
    return pair1[2]<pair2[2]
end

function keys_ordered_by_values{T, S<:Real}(d::Dict{T,S})
    len = length(d)
    items = collect(d) # 1d array containing the (key, value) pairs
    sort!(items, lt=second_less_than)
    return T[pair[1] for pair in items]
end

function mode(v)
    d = countmap(v)
    return keys_ordered_by_values(d)[end]
end


"""
## mutable struct `IntegerSet`

A type of collection for storing subsets of {0, 1, 2, ... 52}. Every
such subset can be stored as an Float64 object. To convert an
IntegerSet object `s` to a floating point number, use Float64(s). To
recover the original object from a float `f`, use `round(IntegerSet,
f)`.

To instantiate an empty collection use, `IntegerSet()`. To add an
element `i::Integer` use `push!(s, i)` which is quickest if `i` is
type `UInt8`. Membership is tested as usual with `in`. One can also
instantiate an object with multiple elements as in the following example:

    julia> 15 in IntegerSet([1, 24, 16])
    false

"""
mutable struct IntegerSet
    coded::Big
end

function IntegerSet(v::AbstractVector{T} where T <: Integer)
    s = IntegerSet()
    for k in v
        push!(s, k) # push! defined below
    end
    return s
end

IntegerSet() = IntegerSet(ZERO)

function Base.in(k::Small, s::IntegerSet)
    large = TWO^k
    return large & s.coded == large
end

function Base.in(k::Integer, s::IntegerSet)
    large = TWO^Small(k)
    return large & s.coded == large
end

function Base.push!(s::IntegerSet, k::Small)
    if k > SMALL_MAX
        throw(Base.error("Cannot push! an integer larger 
           than $(Int(SMALL_MAX)) into an IntegerSet object."))
    end
    if !(k in s)
        s.coded = s.coded | TWO^k
    end
    return s
end

function Base.push!(s::IntegerSet, k::Integer)
    if k > SMALL_MAX
        throw(Base.error("Cannot push! an integer larger 
           than $(Int(SMALL_MAX)) into an IntegerSet object."))
    end
    push!(s, Small(k))
end

function Base.show(stream::IO, s::IntegerSet)
    for i in 0:62
        if i in s
            print(stream, "$i, ")
        end
    end
end

Base.Float64(s::IntegerSet) = Float64(s.coded)

function Base.round(T::Type{IntegerSet}, f::Float64)
    if f < 0 || f > BIG_MAX
        throw(Base.error("Float64 numbers outside the 
           range [0,BIG_MAX] cannot be rounded to IntegerSet values"))
    end
    return IntegerSet(round(Big, f))
end

""" 
Scheme for encoding a mapping from a set of strings (not exceeding 52
in number) to a corresponding number of consecutive SmallFloats,
beginning at 0. Here "SmallFloat" refers to the `Float64`
representation of a `Small` integer.

"""
struct StringToSmallFloatScheme
    small_given_string::Dict{String, Small}
    string_given_small::Dict{Small, String}
    mode::String
    
    function StringToSmallFloatScheme(v::Vector{String}; overide=false)
        small_given_string = Dict{String, Small}()
        string_given_small = Dict{Small, String}()
        vals = sort(collect(Set(v)))
        if length(vals) > SMALL_MAX + 1 && !overide
            throw(Base.error("Trying to construct a StringToSmallFloatScheme with a vector
                             having more than $(SMALL_MAX + 1) values."))
        end
        i = Small(0)
        for c in vals
            small_given_string[c] = i
            string_given_small[i] = c
            i = i + ONE
        end
        return new(small_given_string, string_given_small, mode(v))
    end
end

const VoidScheme=StringToSmallFloatScheme([""])

function show(stream::IO, s::StringToSmallFloatScheme)
    if s == VoidScheme
        print(stream, "VoidScheme")
    else
        print(stream, "StringToSmallFloatScheme@$(tail(hash(s)))")
    end
end

function showall(stream::IO, s::StringToSmallFloatScheme)
    if s == VoidScheme
        show(stream, s)
    else
        show(stream, s)
        str = "\n"
        for k in sort(collect(keys(s.small_given_string)))
            str = string(str, k, " => ", Float64(s.small_given_string[k]), "\n")
        end
        print(stream, str)
    end
end

"""
## `function transform(s::StringToSmallFloatScheme, c::String)`

If the string input `c` does not appear in the dictionary of scheme
`s` then `s.mode` is returned, and a warning issued.

"""
function transform(s::StringToSmallFloatScheme, c::String)
    small = s.mode
    try
        small = s.small_given_string[c]
    catch
        warn("String not in `StringToSmallFloatScheme` encountered in `transform`. "*
             "Using mode.")
        small = s.small_given_string[s.mode]
    end
    return Float64(small)
end

transform(s::StringToSmallFloatScheme, v::Vector{String}) =
    Float64[transform(s, c) for c in v]
inverse_transform(s::StringToSmallFloatScheme, f::Float64) =
    s.string_given_small[round(Small, f)]
inverse_transform(s::StringToSmallFloatScheme, v::Vector{Float64}) =
    String[inverse_transform(s, f) for f in v] 
               

## The `DataTableau` type

struct DataTableauEncoding
    
    schemes::Vector{StringToSmallFloatScheme}
    is_ordinal::Vector{Bool}
    names::Vector{Symbol}
    
end

Base.copy(s::DataTableauEncoding) =
    DataTableauEncoding(copy(s.schemes), copy(s.is_ordinal), copy(s.names))

struct DataTableau

    raw::Array{Float64,2}
    names::Vector{Symbol}
    nrows::Int
    ncols::Int
    encoding::DataTableauEncoding
    
end

copy(X::DataTableau) = DataTableau(copy(X.raw), copy(X.names), X.nrows, X.ncols, copy(X.encoding))

# Before defining `DataTableau` constructors, we need schemes for
# transforming dataframes into datatables:

mutable struct FrameToTableauScheme

    # postfit:
    encoding::DataTableauEncoding

    fitted::Bool

    function FrameToTableauScheme()
        ret = new()
        ret.fitted = false
        return ret
    end

end

function show(stream::IO, s::FrameToTableauScheme)
    print(stream, "FrameToTableauScheme@$(tail(hash(s)))")
end

# Note: we later define `function FrameToTableauScheme(X::DataTableau)`

function fit!(scheme::FrameToTableauScheme, df::AbstractDataFrame)
    ncols = size(df, 2)
    schemes = Array(StringToSmallFloatScheme, ncols)
    is_ordinal = Array(Bool, ncols)
    for j in 1:ncols
        column_type = eltype(df[j])
        if column_type <: Real
            is_ordinal[j] = true
            schemes[j] = VoidScheme
        elseif column_type in [String, Char]
            is_ordinal[j] = false
            col = sort([string(s) for s in df[j]])
            schemes[j] = StringToSmallFloatScheme(col)
        else
            error("I have encountered an AbstractDataFrame column" *
                  " of inadmissable type for transforming to DataTableau constuction.")
        end
    end
    scheme.encoding = DataTableauEncoding(schemes, is_ordinal, names(df))
    scheme.fitted = true
    return scheme
end

function FrameToTableauScheme(df::AbstractDataFrame)
    s = FrameToTableauScheme()
    fit!(s, df)
    return s
end

function transform(scheme::FrameToTableauScheme, df::AbstractDataFrame)

    if !scheme.fitted
        warn("Attempting to transform DataFrame using unfitted FrameToTableauScheme. " *
             "Calling `fit_transform!` instead of `transform`.")
        return fit_transform!(scheme, df)
    end
    
    encoding = scheme.encoding
    
    encoding.names == names(df) || error("Attempt to transform AbstractDataFrame "*
                                         "object into DataTableau object using "*
                                         " incompatible encoding.")
    nrows, ncols = size(df)
    raw    = Array(Float64, (nrows, ncols))
    
    for j in 1:ncols
        if encoding.is_ordinal[j]
            for i in 1:nrows
                raw[i,j] = Float64(df[i,j])
            end
        else
            for i in 1:nrows
                raw[i,j] = transform(encoding.schemes[j], string(df[i,j]))
            end
        end
    end

    return DataTableau(raw, encoding.names, nrows, ncols, encoding)

end

function fit_transform!(s::FrameToTableauScheme, df::AbstractDataFrame)
    fit!(s, df)
    return transform(s, df)
end

function convert(T::Type{DataFrame}, dt::DataTableau)
    return DataFrame(columns(dt), dt.names) # columns(dt) defined later
end

function inverse_transform(s::FrameToTableScheme, df::DataTableau)
    return convert(DataFrame, df)
end

   
# `DataTableau constructors:`

DataTableau(df::AbstractDataFrame) = transform(FrameToTableauScheme(df), df)

function DataTableau(;columns::Vector=Any[], names::Vector{Symbol}=Symbol[])
    ncols = length(columns)
    if ncols == 0
        throw(Base.error("Error constructing DataTableau object. 
                         It must have at least one column."))
    end
    if length(names) != ncols
        throw(Base.error("You must supply one column name per column."))
    end
    
    nrows = length(columns[1])
    if sum([length(v)!=nrows for v in columns]) != 0
        throw(Base.error("Error constructing DataTableau object. 
                         All columns must have same length."))
    end
    df = DataFrame(columns, names)
    return DataTableau(df)
end
                                
function DataTableau(column_tuple...)
    n_cols = length(column_tuple)
    cols = collect(column_tuple)
    colnames = Vector{Symbol}(n_cols)
    for i in 1:n_cols
        colnames[i]=Symbol(string("x",i))
    end
    return DataTableau(columns=cols, names=colnames)
end

function FrameToTableauScheme(X::DataTableau)
    s = FrameToTableauScheme()
    s.encoding = X.encoding
    s.fitted = true
    return s
end

function columns(dt::DataTableau)
    cols = Any[]
    for j in 1:dt.ncols
        rawcol = Float64[dt.raw[i,j] for i in 1:dt.nrows]
        if dt.encoding.is_ordinal[j]
            push!(cols, rawcol)
        else
            push!(cols, inverse_transform(dt.encoding.schemes[j], rawcol))
        end
    end
    return cols
end
                  
function show(stream::IO, dt::DataTableau; nrows=0)
    if nrows == 0
        nrows = dt.nrows
    end
    ncols = dt.ncols
    types = Array(String, ncols)
    for j in 1:ncols
        if dt.encoding.is_ordinal[j]
            types[j] = "ord"
        else
            types[j] = "cat"
        end
    end
    header = [Symbol(string(dt.names[j], " ($j,$(types[j]))")) for j in 1:ncols]
    println("(Displaying DataTableau as DataFrame)")
    show(stream, DataFrame(columns(dt), header)[1:nrows,:])
    println()
end

head(dt::DataTableau) =  show(STDOUT, dt; nrows=min(4, dt.nrows))

getindex(dt::DataTableau, i::Int, j::Int) = dt.raw[i,j]
getindex(dt::DataTableau, j::Int) = dt.raw[:,j]

function getindex(dt::DataTableau, col_name::Symbol)
    j = 0
    for k in eachindex(dt.names)
        if dt.names[k] == col_name
            j = k
        end
    end
    if j == 0
        throw(DomainError)
    end
    return dt[j]
end

function getindex(dt::DataTableau, bs::Vector{Symbol})
    index_given_name = Dict{Symbol,Int}()
    for j in eachindex(dt.names)
        index_given_name[dt.names[j]] = j
    end
    b = [index_given_name[sym] for sym in bs]
    raw = dt.raw[:,b] 
    col_names = dt.names[b]
    nrows = dt.nrows
    ncols = length(b)
    encoding = DataTableauEncoding(dt.encoding.schemes[b], dt.encoding.is_ordinal[b], bs)
    return DataTableau(raw, col_names, nrows, ncols, encoding)    
end

# function getindex(dt::DataTableau, c::Colon, j::Int)
#     raw = dt.raw[:,j:j] # j:j forces two-dimensionality of the array
#     col_names = dt.names[j:j]
#     nrows = dt.nrows
#     ncols = 1
#     encoding = DataTableauEncoding()
#     encoding.schemes = dt.encoding.schemes[j:j]
#     encoding.is_ordinal = dt.encoding.is_ordinal[j:j]
#     return DataTableau(raw, col_names, nrows, ncols, encoding)    
# end

getindex(dt::DataTableau, c::Colon, j::Int) = dt.raw[:,j]
getindex(dt::DataTableau, i::Int, c::Colon) = dt.raw[i,:]
row(dt::DataTableau, i::Int) = dt.raw[i,:]

function getindex(dt::DataTableau, a::Vector{Int}, c::Colon)
    raw = dt.raw[a,:]
    col_names = dt.names
    nrows = length(a)
    ncols = dt.ncols
    encoding = dt.encoding
    return DataTableau(raw, col_names, nrows, ncols, encoding)    
end

getindex(dt::DataTableau, a::UnitRange{Int}, c::Colon) = dt[collect(a),:]

function getindex(dt::DataTableau, c::Colon, b::Vector{Int})
    raw = dt.raw[:,b]
    col_names = dt.names[b]
    nrows = dt.nrows
    ncols = length(b)
    encoding = DataTableauEncoding(dt.encoding.schemes[b], dt.encoding.is_ordinal[b], col_names)
    return DataTableau(raw, col_names, nrows, ncols, encoding)
end

getindex(dt::DataTableau, c::Colon, b::UnitRange{Int}) = dt[:,collect(b)]

function getindex(dt::DataTableau, a::Vector{Int}, b::Vector{Int})
    raw = dt.raw[a,b]
    col_names = dt.names[b]
    nrows = length(a)
    ncols = length(b)
    encoding = DataTableauEncoding(dt.encoding.schemes[b], dt.encoding.is_ordinal[b], col_names)
    return DataTableau(raw, col_names, nrows, ncols, encoding)
end
getindex(dt::DataTableau, a::UnitRange{Int}, b::UnitRange{Int}) = dt[collect(a),collect(b)]
getindex(dt::DataTableau, a::UnitRange{Int}, b::Vector{Int}) = dt[collect(a),b]
getindex(dt::DataTableau, a::Vector{Int}, b::UnitRange{Int}) = dt[a,collect(b)]

length(dt::DataTableau) = dt.ncols
issparse(dt::DataTableau) = false
ndims(dt::DataTableau) = 2
size(dt::DataTableau) = (dt.nrows, dt.ncols)
size(dt::DataTableau, n::Integer) = (n == 1 ? dt.nrows : dt.ncols)

function size(dt::DataTableau, i::Int)
    if  i == 1
        return dt.nrows
    elseif i == 2
        return dt.ncols
    else
        throw(BoundsError)
    end
end

# Iteration methods:
start(dt::DataTableau) = 1
next(dt::DataTableau, i) = (dt[i], i + 1)
done(dt::DataTableau, i) = (i > dt.ncols)              

end # of module


