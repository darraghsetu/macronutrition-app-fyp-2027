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

# 4. Total cost should be minimised
total_cost = sum(ingredients.price_in_eur[i] * y[i] for i in 1:I)

# 5. Food waste should be minimised
total_waste_grams = sum((ingredients.package_size[i] * y[i]) - x[i] for i in 1:I)

## Objective function

# The model equally minimises going over caloric goal or under protein goal
@objective(model, Min, 
   1.0 * total_cost + 
   10.0 * d_protein_under + 
   10.0 * d_kcal_over +
   0.01 * total_waste_grams
)

### Output

optimize!(model)

println("### Optimisation results ###")
println("Termination Status: $(termination_status(model))")
println("Objective Value: $(objective_value(model))")
println("Total cost: $(round(JuMP.value(total_cost), digits=2))")
println("Total Protein:      $(round(JuMP.value(total_protein), digits=1)) g (Target: $target_protein)")
println("Total Calories:     $(round(JuMP.value(total_kcal), digits=1)) kcal (Target: $target_kcal)")
println("Total Waste:        $(round(JuMP.value(total_waste_grams), digits=1)) g")

println("\n### Ingredient list ###")

for i in 1:I
    bought_packs = JuMP.value(y[i])
    
    if bought_packs > 0
        consumed_g = JuMP.value(x[i])
        bought_g = bought_packs * ingredients.package_size[i]
        waste_g = bought_g - consumed_g
        item_cost = bought_packs * ingredients.price_in_eur[i]

        println("$(ingredients.brand[i]) $(ingredients.name[i])")
        println("Bought:   $(Int(bought_packs)) pack(s) [$(bought_g)g] for €$(round(item_cost, digits=2))")
        println("Consume: $(round(consumed_g, digits=1))g")
        println("Waste:   $(round(waste_g, digits=1))g")
        println("")
    end
end
