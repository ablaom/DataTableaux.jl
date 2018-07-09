using DataTableaux
using Base.Test

# construct a `DataTableau` object directly:
employees = ["Bob", "Ann", "Bob"]
hours = [10.0, 12.0, 15.0]
dt = DataTableau(columns = Any[employees, hours], names = [:employee, :hours])

# or, with automatic naming of columns:
dt = DataTableau(columns = Any[employees, hours])

# load a reduced Ames House Price data set as a `DataFrame`:
df = DataTableaux.load_reduced_ames()

# make integer types float (else considered categorical):
for ftr in names(df)
    if eltype(df[ftr]) <: Integer
        df[ftr] = convert(Array{Float64}, df[ftr])
    end
end

# split into train and test sets:
ntrain = round(Int, 0.8*size(df,1))
train = 1:ntrain
test = (ntrain + 1):size(df,1)
df_test = df[test,:]
df = df[train,:]

# construct a `DataTableau` object:
dt = DataTableau(df) 
@test dt.names == names(df)

# recover the scheme encoding the transformation from `df` to `dt`:
s = FrameToTableauScheme(dt)

# transform the test data according to the same scheme:
dt_test = DataTableaux.transform(s, df_test)

# recover the original test `DataFrame` object from `dt`:
@test df == DataTableaux.inverse_transform(s, dt) 

# construct an unfitted transformation scheme
s = FrameToTableauScheme()

# fit to the training `DataFrame` (return value:
DataTableaux.fit!(s, df) 

# obtain the corresponding `DataTableaux` object:
dt2 = DataTableaux.transform(s, df)

# which amounts to the same construction given above:
@test dt2.raw == dt.raw

# alternatively, perform the preceding construction in one less step
# with `fit_transform!`:
s = FrameToTableauScheme()
dt3 = DataTableaux.fit_transform!(s, df)
@test dt3.raw == dt.raw

# test `getindex`
dt[10:12,:]


