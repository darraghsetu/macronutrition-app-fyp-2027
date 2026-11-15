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
@variable(model, d_protein_over >= 0)

@variable(model, d_kcal_under >= 0)
@variable(model, d_kcal_over >= 0)

## Constraints

# 1. The model cannot consume more grams of ingredient i than it buys
for i in 1:I
    @constraint(model, x[i] <= ingredients.package_size[i] * y[i])
end

# 2. Protein goal: Target + under - over = actual 
total_protein = sum((ingredients.protein_per_100g[i] / 100.0) * x[i] for i in 1:I)
@constraint(model, total_protein + d_protein_under - d_protein_over == target_protein)

# 3. Calorie goal: Target + under - over = actual 
total_kcal = sum((ingredients.kcal_per_100g[i] / 100.0) * x[i] for i in 1:I)
@constraint(model, total_kcal + d_kcal_under - d_kcal_over == target_kcal)

## Objective function

# The model equally minimises going over caloric goal or under protein goal
@objective(model, Min, 10.0 * d_protein_under + 10.0 * d_kcal_over)

