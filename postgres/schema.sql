-- TODO:
-- Add pgvector vectors 
-- Add indexes

-- User tables

CREATE TABLE users (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE user_goals (
  user_id INT PRIMARY KEY REFERENCES users(id),
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
  user_id INT NOT NULL REFERENCES users(id),
  restriction_id INT NOT NULL REFERENCES dietary_restrictions(id),
  PRIMARY KEY (user_id, restriction_id)
);

-- Ingredients tables

CREATE TABLE ingredient_categories (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL -- 'protein', 'vegetable', ...
);

CREATE TABLE ingredients (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  category_id INT NOT NULL REFERENCES ingredient_categories(id),
  protein_per_100g NUMERIC NOT NULL, 
  carbs_per_100g NUMERIC NOT NULL,
  fat_per_100g NUMERIC NOT NULL,
  kcal_per_100g NUMERIC NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
);

-- Row present = ingredient complies with the restriction
CREATE TABLE ingredient_dietary_restrictions (
  ingredient_id INT NOT NULL REFERENCES ingredients(id),
  restriction_id INT NOT NULL REFERENCES dietary_restrictions(id),
  PRIMARY KEY (ingredient_id, restriction_id)
);

-- Recipes tables

CREATE TABLE recipes (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title_template VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL
);

CREATE TABLE meal_categories (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL -- 'Breakfast', 'Lunch', 'Dinner', 'Snack'
);
