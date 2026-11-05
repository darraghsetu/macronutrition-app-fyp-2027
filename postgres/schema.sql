CREATE EXTENSION IF NOT EXISTS vector; -- pgvector
CREATE EXTENSION IF NOT EXISTS citext; -- case insensitive text type for users.email
                                       -- a@domain.com === A@domain.com

-- TODO:
-- Add views?

-- User tables

CREATE TABLE users (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email CITEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_goals (
  user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_calories NUMERIC(7,2) NOT NULL CHECK (daily_calories >= 0),
  daily_protein NUMERIC(6,2) NOT NULL CHECK (daily_protein >= 0),
  daily_carbs NUMERIC(6,2) NOT NULL CHECK (daily_carbs >= 0),
  daily_fat NUMERIC(6,2) NOT NULL CHECK (daily_fat >= 0)
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

-- mass = g
-- volume = ml
-- unit = integer value e.g. 1 banana
CREATE TYPE ingredient_unit_type AS ENUM ('mass', 'volume', 'unit');

CREATE TABLE ingredients (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  category_id INT NOT NULL REFERENCES ingredient_categories(id),
  unit_type ingredient_unit_type NOT NULL DEFAULT 'mass',
  unit_weight_grams NUMERIC(6,2),
  kcal_per_100g NUMERIC(6,2) NOT NULL CHECK (kcal_per_100g BETWEEN 0 AND 900),
  protein_per_100g NUMERIC(6,2) NOT NULL CHECK (protein_per_100g >= 0),
  carbs_per_100g NUMERIC(6,2) NOT NULL CHECK (carbs_per_100g >= 0),
  fat_per_100g NUMERIC(6,2) NOT NULL CHECK (fat_per_100g >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  macro_vector vector(3) GENERATED ALWAYS AS (
    ARRAY[protein_per_100g, carbs_per_100g, fat_per_100g]::real[]::vector(3)
  ) STORED,

  CHECK (protein_per_100g + carbs_per_100g + fat_per_100g <= 100)
  CONSTRAINT check_unit_weight CHECK (
    (unit_type = 'discrete_unit' AND unit_weight_grams IS NOT NULL AND unit_weight > 0)
    OR
    (unit_type != 'discrete_unit' AND unit_weight_grams IS NULL)
  )
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
    min_selections INT NOT NULL DEFAULT 1 CHECK (min_selections >= 0),
    max_selections INT NOT NULL DEFAULT 1 CHECK (max_selections >= 1),

    UNIQUE (recipe_id, slot_name),
    CHECK (max_selections >= min_selections)
);

CREATE TABLE slot_options (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slot_id INT NOT NULL REFERENCES recipe_slots(id) ON DELETE CASCADE,
    ingredient_id INT NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
    default_grams NUMERIC(7,2) NOT NULL CHECK (default_grams > 0),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    min_multiplier NUMERIC(4,2) NOT NULL DEFAULT 0.6 CHECK (min_multiplier > 0),
    max_multiplier NUMERIC(4,2) NOT NULL DEFAULT 2.0,
    min_grams NUMERIC GENERATED ALWAYS AS (default_grams * min_multiplier) STORED,
    max_grams NUMERIC GENERATED ALWAYS AS (default_grams * max_multiplier) STORED,

    UNIQUE (slot_id, ingredient_id),
    CHECK (min_multiplier <= 1 AND max_multiplier >= 1)
);
CREATE INDEX ON slot_options(ingredient_id);

-- Solver output tables

CREATE TABLE user_meal_plans (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_date DATE NOT NULL,
    solver_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    UNIQUE (user_id, plan_date)
);

CREATE TABLE meal_plan_items (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    meal_plan_id INT NOT NULL REFERENCES user_meal_plans(id) ON DELETE CASCADE,
    recipe_id INT NOT NULL REFERENCES recipes(id) ON DELETE RESTRICT,
    meal_category_id INT NOT NULL REFERENCES meal_categories(id) ON DELETE RESTRICT,
    final_calories NUMERIC(8,2) NOT NULL,
    final_protein NUMERIC(8,2) NOT NULL,
    final_carbs NUMERIC(8,2) NOT NULL,
    final_fat NUMERIC(8,2) NOT NULL,
    FOREIGN KEY (recipe_id, meal_category_id) REFERENCES recipe_categories(recipe_id, category_id)
);
CREATE INDEX ON meal_plan_items(meal_plan_id);
CREATE INDEX ON meal_plan_items(recipe_id);

CREATE TABLE meal_plan_item_ingredients (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    meal_plan_item_id INT NOT NULL REFERENCES meal_plan_items(id) ON DELETE CASCADE,
    slot_option_id INT NOT NULL REFERENCES slot_options(id) ON DELETE RESTRICT,
    grams NUMERIC(7,2) NOT NULL CHECK (grams > 0),

    UNIQUE (meal_plan_item_id, slot_option_id)
);
CREATE INDEX ON meal_plan_item_ingredients(slot_option_id);
