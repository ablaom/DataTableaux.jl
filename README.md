# `DataTableaux.jl`: an alternative to `DataFrames.jl` for tree-based
  learning algorithms

A `DataTableau` object is an immutable data structure that presents
externally as a `DataFrame` object whose columns are a mixture of
categorical and ordinal type. Internally, however it stores this data
as an ordinary `Float64` array that can then be passed to
high-performance tree-based machine learning algorithms. The number of
values taken by a categorical feature in this data structure is
intentionally limited to 53.  This is because at nodes of a decision
tree or tree regressor the criterion for a binary split based on such
a feature (specifically, a subset of \\(\{1, 2, 3, \ldots, 53\}\\) can
be encoded in a single `Float64` number, just as the threshold for
ordinal features. The nodes in such a tree can therefore be of
homogeneous type.

The `Float64` array encoding the data is stored in the field
`raw::Array{Float64, 2}`. The other fields are `names`, `nrows` and
`ncols` (which are self-explanatory) and a field `scheme` (of type
`FrameToTableauScheme`) which stores information on which columns are
categorical and how to transform back and forth between a categorical
feature and its equivalent floating point representation.

## Constuctors

`DataTableau` objects can be constructed directly:

    julia> using DataTableaux
    julia> employees = ["Bob", "Ann", "Bob"]
    julia> hours = [10, 12, 15]
    julia> dt = DataTableau(columns = Any[employees, hours], names = [:employee, :hours])

    3×2 DataFrames.DataFrame
    │ Row │ employee (1,cat) │ hours (2,ord) │
    ├─────┼──────────────────┼───────────────┤
    │ 1   │ Bob              │ 10.0          │
    │ 2   │ Ann              │ 12.0          │
    │ 3   │ Bob              │ 15.0          │

    # or, with automatic naming of columns:
    julia> dt = DataTableau(columns = Any[employees, hours])

    │ Row │ x1 (1,cat) │ x2 (2,ord) │
    ├─────┼────────────┼────────────┤
    │ 1   │ Bob        │ 10.0       │
    │ 2   │ Ann        │ 12.0       │
    │ 3   │ Bob        │ 15.0       │

Note that in the all constructors treat numerical features (eltype a
subtype of `Real`) as ordinals and all features of `Char` or
`AbstractString` as identified as categorical, which become `Float64`
integers in the internal representation:

    julia> dt.raw

    3×2 Array{Float64,2}:
    1.0  10.0
    0.0  12.0
    1.0  15.0

More usually be contructing `DataTableau` objects from existing
`DataFrame` objects; there are methods provided to do this:

    # load a reduced Ames House Price data set as a `DataFrame`:
    df = DataTableaux.load_reduced_ames()

    # split into train and test sets:
    ntrain = round(Int, 0.8*size(df,1))
    train = 1:ntrain
    test = (ntrain + 1):size(df,1)
    df_test = df[test,:]
    df = df[train,:]

    # construct a `DataTableau` object:
    dt = DataTableau(df) 
    dt.names == names(df) # true

    # recover the scheme encoding the transformation from `df` to `dt`:
    s = FrameToTableauScheme(dt)

    # transform the test data according to the same scheme:
    dt_test = DataTableaux.transform(s, df_test)

    # recover the original test `DataFrame` object from `dt`:
    df == DataTableaux.inverse_transform(s, dt) # true

    # construct an unfitted transformation scheme
    s = FrameToTableauScheme()

    # fit to the training `DataFrame` (return value:
    DataTableaux.fit!(s, df) 

    # obtain the corresponding `DataTableaux` object:
    dt2 = DataTableaux.transform(s, df)

    # which amounts to the same construction given above:
    dt2.raw == dt.raw # true

    # alternatively, perform the preceding construction in one less step
    # with `fit_transform!`:
    s = FrameToTableauScheme()
    dt3 = DataTableaux.fit_transform!(s, df)
    dt3.raw == dt.raw # true

Note that the `fit!`, `transform`, `inverse_transform` and
`fit_transform!` methods are not brought explicity into scope with
`using DataTableaux` to avoid conflict with methods of the same name
in many machine learning packages.

## Iteration

One can iterate over the columns of the `DataTableau` and some basic
indexing for retrieving (but not setting) elements is
implemented. There is a `row` method.

## Other methods

Sample use of some implemented methods:

    `length(dt), size(dt), convert(DataFrame, dt), head(dt), countmap(dt[1])`


## `IntegerSet`

Query with `?IntegerSet` to see how to switch between subsets of the
first 52 `Small` integers and `Float64's.


