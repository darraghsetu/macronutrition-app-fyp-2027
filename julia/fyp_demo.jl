using JuMP
#using HiGHS
using Gurobi
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

### Other Variables ###

days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
#days = ["Monday", "Tuesday", "Wednesday"]
D = length(days)

### Modelling ###

#model = Model(HiGHS.Optimizer)
model = Model(Gurobi.Optimizer)

## Solver Configuration
set_optimizer_attribute(model, "MIPGap", 0.02) # Accept 2% optimality gap
#set_optimizer_attribute(model, "threads", 4)
set_optimizer_attribute(model, "time_limit", 3.0)
set_optimizer_attribute(model, "Presolve", 2)      # Ensure deep presolve is active

## Decision Variables

# x[i][d]: number of grams consumed from the packages (y[i])
@variable(model, x[1:I, 1:D] >= 0)

# y[i][d]: number of packages to buy for ingredient i
@variable(model, y[1:I, 1:D] >= 0, Int)

# z[i][d]: ingredient i is used on day d
@variable(model, z[1:I, 1:D], Bin) # Binary choice (0,1), 1 if ingredient i is consumed on day d

# Deviations from the goals per day
@variable(model, d_protein_under[1:D] >= 0)
@variable(model, d_protein_over[1:D] >= 0)

@variable(model, d_kcal_under[1:D] >= 0)
@variable(model, d_kcal_over[1:D] >= 0)

# Variable to track stock / inventory across days
# S[i, d]: Stock of ingredient i at the end of day d (grams)
@variable(model, S[1:I, 0:D] >= 0)

for i in 1:I
    # The stock for each ingredient on 'day 0' is 0 grams
    @constraint(model, S[i, 0] == 0)
end

## Constraints

for d in 1:D
    for i in 1:I
        # 1. The model cannot consume more grams of ingredient i than it has in stock + 'buys' for today
        @constraint(model, x[i, d] <= S[i, d-1] + (ingredients.package_size[i] * y[i, d]))

        # 2. End of day inventory: Stock = previous days stock + purchases - consumed
        @constraint(model, S[i, d] == S[i, d-1] + (ingredients.package_size[i] * y[i, d]) - x[i, d])
        # 3. Links binary indicator (z) with purchases (y) per day
        max_daily_consumption = ingredients.package_size[i] * 2
        @constraint(model, x[i, d] <= max_daily_consumption * z[i, d])
    end

    # 4. Protein goal: Target + under - over = actual 
    daily_protein = sum((ingredients.protein_per_100g[i] / 100.0) * x[i, d] for i in 1:I)
    @constraint(model, daily_protein + d_protein_under[d] - d_protein_over[d] == target_protein)

    # 5. Calorie goal: Target + under - over = actual 
    daily_kcal = sum((ingredients.kcal_per_100g[i] / 100.0) * x[i, d] for i in 1:I)
    @constraint(model, daily_kcal + d_kcal_under[d] - d_kcal_over[d] == target_kcal)

    # 6. Enforce daily bounds
    # i.e. no day should be under / over for a macro within a upper / lower limit
    protein_lower_bound_percentage = 0.75
    kcal_lower_bound_percentage = 0.75
    kcal_upper_bound_percentage = 1.25
    @constraint(model, daily_protein >= target_protein * protein_lower_bound_percentage)
    @constraint(model, daily_kcal >= target_kcal * kcal_lower_bound_percentage)
    @constraint(model, daily_kcal <= target_kcal * kcal_upper_bound_percentage)
end

# 6. Total weekly cost should be minimised
total_cost = sum(ingredients.price_in_eur[i] * y[i, d] for i in 1:I, d in 1:D)

# 7. Food waste should be minimised
total_waste_money = sum(S[i, D] * (ingredients.price_in_eur[i] / ingredients.package_size[i]) for i in 1:I) 

# 8. Repitition should be minimised
# total_repitition_penalty = sum(z[i, d] for i in 1:I, d in 1:D)

# 8. No single ingredient category can be consumed more than twice
categories = unique(ingredients.category)
max_category_days = 2

for c in categories
    indices_in_cat = findall(ingredients.category .== c)
    @constraint(model, sum(z[i, d] for i in indices_in_cat, d in 1:D) <= max_category_days)
end

## Objective function

# The model equally minimises going over caloric goal or under protein goal
@objective(model, Min, 
    1.0 * total_cost + 
    sum( 
        10.0 * d_protein_under[d] + 
        10.0 * d_kcal_over[d]
        for d in 1:D
    ) 
    + 1.0 * total_waste_money
    # + 15.0 * total_repitition_penalty 
)

### Output

optimize!(model)
status = termination_status(model)

println("### Optimisation results ###")
println("Termination Status: $(status)")

if status == MOI.OPTIMAL || status == MOI.TIME_LIMIT
    println("Objective Value: $(objective_value(model))")
    println("Week's total cost: €$(round(JuMP.value(total_cost), digits=2))")
    println("Week's total food waste: €$(round(JuMP.value(total_waste_money), digits=2))")

    weekly_protein = sum(JuMP.value(ingredients.protein_per_100g[i] / 100.0 * x[i, d]) for i in 1:I, d in 1:D)
    weekly_kcal = sum(JuMP.value(ingredients.kcal_per_100g[i] / 100.0 * x[i, d]) for i in 1:I, d in 1:D)
    target_weekly_protein = target_protein * D
    target_weekly_kcal = target_kcal * D

    println("Weekly Protein: $(round(weekly_protein, digits=1))g (Target: $(target_weekly_protein)g)")
    println("Weekly Calories: $(round(weekly_kcal, digits=1)) kcal (Target: $(target_weekly_kcal) kcal)")

    println("\n### Daily Ingredient List ###")

    for d in 1:D
        println("\n Day $(days[d])")

        day_prot = sum(JuMP.value(ingredients.protein_per_100g[i] / 100.0 * x[i, d]) for i in 1:I)
        day_kcal = sum(JuMP.value(ingredients.kcal_per_100g[i] / 100.0 * x[i, d]) for i in 1:I)

        println("Achieved:")
        println("$(round(day_prot, digits=1))g protein")
        println("$(round(day_kcal, digits=1)) kcal")

        for i in 1:I
            bought_packs = JuMP.value(y[i, d])
            consumed_grams = JuMP.value(x[i, d])
            
            if bought_packs > 0.001 || consumed_grams > 0.001
                println("$(ingredients.brand[i]) $(ingredients.name[i])")

                if bought_packs > 0.001
                    println("Bought: $(Int(round(bought_packs))) pack(s) [$(Int(round(bought_packs * ingredients.package_size[i])))g]")
                end

                println("Consumed: $(round(consumed_grams, digits=1))g")
            end
        end
    end

    println("Remaining Stock:")

    leftover_items = false
    for i in 1:I
        leftover_g = JuMP.value(S[i, D])
        if leftover_g > 0.1
            global leftover_items = true
            value_left = leftover_g * (ingredients.price_in_eur[i] / ingredients.package_size[i])
            println("$(ingredients.brand[i]) $(ingredients.name[i]): $(round(leftover_g, digits=1))g left (€$(round(value_left, digits=2)))")
        end
    end

    if !leftover_items
        println("Zero inventory left at the end of the week (zero waste).")
    end
elseif status == MOI.INFEASIBLE
    println("The model is infeasible. Rerun with relaxed constraints.")
else
    println("Optimisation stopped with status: $(status)")
end
