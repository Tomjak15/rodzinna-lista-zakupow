create table if not exists families (
  id text primary key,
  family_id text not null unique,
  name text not null,
  code text not null unique,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0,
  check (family_id = id)
);

create table if not exists members (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  avatar_url text,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists shopping_items (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  name text not null,
  quantity real not null default 1,
  unit text not null default 'szt.',
  category text,
  author_name text not null default '',
  is_purchased integer not null default 0,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists meals (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  name text not null,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists recipes (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  meal_id text not null references meals(id) on delete cascade,
  parent_recipe_id text references recipes(id) on delete cascade,
  name text not null,
  recipe_category text not null default 'Obiady',
  instructions text not null default '',
  base_servings integer not null default 4,
  calories_per_serving integer not null default 0,
  protein_per_serving real not null default 0,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists recipe_ingredients (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  recipe_id text not null references recipes(id) on delete cascade,
  name text not null,
  quantity real not null default 1,
  unit text not null default 'szt.',
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists meal_plans (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  date text not null,
  meal_id text not null references meals(id) on delete cascade,
  recipe_ids text not null default '',
  servings integer not null default 1,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists calendar_events (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  event_date text not null,
  title text not null,
  notes text not null default '',
  member_id text references members(id) on delete set null,
  is_family_wide integer not null default 1,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists nutrition_goals (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  member_id text not null references members(id) on delete cascade,
  daily_calories integer not null default 0,
  daily_protein real not null default 0,
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists nutrition_entries (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  member_id text not null references members(id) on delete cascade,
  entry_date text not null,
  calories integer not null default 0,
  protein real not null default 0,
  note text not null default '',
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists training_entries (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  member_id text not null references members(id) on delete cascade,
  training_date text not null,
  activity text not null default 'Trening',
  duration_minutes integer not null default 0,
  note text not null default '',
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists favorite_products (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  name text not null,
  quantity real not null default 1,
  unit text not null default 'szt.',
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create table if not exists receipts (
  id text primary key,
  family_id text not null references families(id) on delete cascade,
  store_name text not null default 'Sklep',
  purchased_at text not null,
  total real not null default 0,
  raw_text text not null default '',
  image_data text,
  image_mime_type text,
  items_json text not null default '[]',
  created_at text not null,
  updated_at text not null,
  created_by text not null,
  is_deleted integer not null default 0
);

create index if not exists families_code_idx on families (code);
create index if not exists members_family_id_idx on members (family_id);
create index if not exists shopping_items_family_id_idx on shopping_items (family_id);
create index if not exists meals_family_id_idx on meals (family_id);
create index if not exists recipes_family_id_idx on recipes (family_id);
create index if not exists recipes_meal_id_idx on recipes (meal_id);
create index if not exists recipes_parent_recipe_id_idx on recipes (parent_recipe_id);
create index if not exists recipe_ingredients_family_id_idx on recipe_ingredients (family_id);
create index if not exists recipe_ingredients_recipe_id_idx on recipe_ingredients (recipe_id);
create index if not exists meal_plans_family_id_idx on meal_plans (family_id);
create index if not exists meal_plans_date_idx on meal_plans (date);
create index if not exists calendar_events_family_id_idx on calendar_events (family_id);
create index if not exists calendar_events_date_idx on calendar_events (event_date);
create index if not exists nutrition_goals_family_id_idx on nutrition_goals (family_id);
create index if not exists nutrition_goals_member_id_idx on nutrition_goals (member_id);
create index if not exists nutrition_entries_family_id_idx on nutrition_entries (family_id);
create index if not exists nutrition_entries_date_idx on nutrition_entries (entry_date);
create index if not exists training_entries_family_id_idx on training_entries (family_id);
create index if not exists training_entries_member_id_idx on training_entries (member_id);
create index if not exists training_entries_date_idx on training_entries (training_date);
create index if not exists favorite_products_family_id_idx on favorite_products (family_id);
create index if not exists receipts_family_id_idx on receipts (family_id);
create index if not exists receipts_purchased_at_idx on receipts (purchased_at);
