-- TODO:
-- Add pgvector vectors 
-- Add constraint checks
-- Add views?

-- User tables

CREATE TABLE users (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE user_goals (
  user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_calories NUMERIC NOT NULL,
  daily_protein NUMERIC NOT NULL,
  daily_carbs NUMERIC NOT NULL,
  daily_fat NUMERIC NOT NULL
);

CREATE TABLE dietary_restrictions (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE user_dietary_restrictions (
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restriction_id INT NOT NULL REFERENCES dietary_restrictions(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, restriction_id)
);
CREATE INDEX ON user_dietary_restrictions(restriction_id);

-- Ingredients tables

CREATE TABLE ingredient_categories (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL -- 'protein', 'vegetable', etc.
);

CREATE TABLE ingredients (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  category_id INT NOT NULL REFERENCES ingredient_categories(id),
  protein_per_100g NUMERIC NOT NULL, 
  carbs_per_100g NUMERIC NOT NULL,
  fat_per_100g NUMERIC NOT NULL,
  kcal_per_100g NUMERIC NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX ON ingredients(category_id);

-- Row present = ingredient complies with the restriction
CREATE TABLE ingredient_dietary_restrictions (
  ingredient_id INT NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  restriction_id INT NOT NULL REFERENCES dietary_restrictions(id) ON DELETE CASCADE,
  PRIMARY KEY (ingredient_id, restriction_id)
);
CREATE INDEX ON ingredient_dietary_restrictions(restriction_id);

-- Recipes tables

CREATE TABLE recipes (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title_template VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE meal_categories (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL, -- 'Breakfast', 'Lunch', 'Dinner', 'Snack'
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE recipe_categories (
    recipe_id INT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES meal_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (recipe_id, category_id)
);
CREATE INDEX ON recipe_categories(category_id);

CREATE TABLE recipe_slots (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recipe_id INT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    slot_name VARCHAR(100) NOT NULL,
    min_selections INT NOT NULL,
    max_selections INT NOT NULL
);

CREATE TABLE slot_options (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slot_id INT NOT NULL REFERENCES recipe_slots(id) ON DELETE CASCADE,
    ingredient_id INT NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
    default_grams NUMERIC NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    min_multiplier NUMERIC NOT NULL,
    max_multiplier NUMERIC NOT NULL
);
CREATE INDEX ON slot_options(ingredient_id);

-- Solver output tables

CREATE TABLE user_meal_plans (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_date DATE NOT NULL,
    solver_status TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE meal_plan_items (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    meal_plan_id INT NOT NULL REFERENCES user_meal_plans(id) ON DELETE CASCADE,
    recipe_id INT NOT NULL REFERENCES recipes(id) ON DELETE RESTRICT,
    meal_category_id INT NOT NULL REFERENCES meal_categories(id) ON DELETE CASCADE,
    final_calories NUMERIC NOT NULL,
    final_protein NUMERIC NOT NULL,
    final_carbs NUMERIC NOT NULL,
    final_fat NUMERIC NOT NULL,
    FOREIGN KEY (recipe_id, meal_category_id) REFERENCES recipe_categories(recipe_id, category_id)
);
CREATE INDEX ON meal_plan_items(meal_plan_id);
CREATE INDEX ON meal_plan_items(recipe_id);

CREATE TABLE meal_plan_item_ingredients (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    meal_plan_item_id INT NOT NULL REFERENCES meal_plan_items(id) ON DELETE CASCADE,
    slot_option_id INT NOT NULL REFERENCES slot_options(id) ON DELETE RESTRICT,
    grams NUMERIC NOT NULL,
);
CREATE INDEX ON meal_plan_item_ingredients(slot_option_id);
