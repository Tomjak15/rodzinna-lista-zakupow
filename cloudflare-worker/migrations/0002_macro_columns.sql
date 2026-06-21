alter table recipes add column fat_per_serving real not null default 0;
alter table recipes add column carbs_per_serving real not null default 0;
alter table nutrition_goals add column daily_fat real not null default 0;
alter table nutrition_goals add column daily_carbs real not null default 0;
alter table nutrition_entries add column fat real not null default 0;
alter table nutrition_entries add column carbs real not null default 0;
