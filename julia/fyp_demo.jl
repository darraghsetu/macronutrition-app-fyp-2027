using JuMP
using HiGHS
using CSV
using DataFrames

### Import ingredient data ###

ingredients = CSV.read("ingredients_demo.csv", DataFrame)
I = nrow(ingredients)

println("Loaded $(I) ingredients")

### User Goals ###

print("Enter target daily calories (kcal): ")
input_kcal = readline()
target_kcal = isempty(input_kcal) ? 2000.0 : parse(Float64, input_kcal)

print("Enter target daily protein in grams: ")
input_protein = readline()
target_protein = isempty(input_protein) ? 140.0 : parse(Float64, input_protein)

println("Running optimisation for $(target_kcal) kcal, $(target_protein)g protein.")

### Modelling ###

model = Model(HiGHS.Optimizer)

## Decision Variables

# x[i]: number of grams consumed from the packages (y[i])
@variable(model, x[1:I] >= 0)

# y[i]: number of packages to buy for ingredient i
@variable(model, y[1:I] >= 0, Int)

# Deviations from the goals
@variable(model, d_protein_under >= 0)
@variable(model, d_kcal_over >= 0)

