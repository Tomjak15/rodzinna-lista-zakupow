const fs = require("node:fs");
const path = require("node:path");

const Database = require("better-sqlite3");
const cors = require("cors");
const express = require("express");
const morgan = require("morgan");

const app = express();
const port = process.env.PORT || 3000;
const dbPath =
  process.env.DB_PATH ||
  path.join(process.env.DATA_DIR || path.join(__dirname, "data"), "rodzinna_lista.sqlite");

fs.mkdirSync(path.dirname(dbPath), { recursive: true });

const db = new Database(dbPath);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

const tables = {
  families: {
    columns: [
      "id",
      "family_id",
      "name",
      "code",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: [],
  },
  members: {
    columns: [
      "id",
      "family_id",
      "name",
      "email",
      "phone",
      "avatar_url",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: [],
  },
  shopping_items: {
    columns: [
      "id",
      "family_id",
      "name",
      "quantity",
      "unit",
      "author_name",
      "is_purchased",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_purchased", "is_deleted"],
    numberColumns: ["quantity"],
  },
  meals: {
    columns: [
      "id",
      "family_id",
      "name",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: [],
  },
  recipes: {
    columns: [
      "id",
      "family_id",
      "meal_id",
      "parent_recipe_id",
      "name",
      "instructions",
      "base_servings",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["base_servings"],
  },
  recipe_ingredients: {
    columns: [
      "id",
      "family_id",
      "recipe_id",
      "name",
      "quantity",
      "unit",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["quantity"],
  },
  meal_plans: {
    columns: [
      "id",
      "family_id",
      "date",
      "meal_id",
      "recipe_ids",
      "servings",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["servings"],
  },
  calendar_events: {
    columns: [
      "id",
      "family_id",
      "event_date",
      "title",
      "notes",
      "member_id",
      "is_family_wide",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_family_wide", "is_deleted"],
    numberColumns: [],
  },
};

initializeDatabase();

app.use(cors());
app.use(express.json({ limit: "2mb" }));
app.use(morgan("tiny"));

app.get("/", (_req, res) => {
  res.json({
    name: "Rodzinna Lista Zakupów API",
    status: "ok",
    health: "/api/health",
  });
});

app.get("/api/health", (_req, res) => {
  res.json({
    ok: true,
    database: path.basename(dbPath),
    tables: Object.keys(tables),
  });
});

app.get("/api/families/code/:code", (req, res) => {
  const row = db
    .prepare(
      "select * from families where upper(code) = upper(?) and is_deleted = 0 limit 1",
    )
    .get(req.params.code);

  if (!row) {
    res.status(404).json({ error: "Rodzina o takim kodzie nie istnieje." });
    return;
  }

  res.json(rowToApi("families", row));
});

app.get("/api/:table", (req, res) => {
  const table = requireTable(req.params.table);
  const familyId = req.query.familyId?.toString();

  if (!familyId) {
    res.status(400).json({ error: "Brakuje parametru familyId." });
    return;
  }

  const rows = db
    .prepare(`select * from ${table} where family_id = ? order by updated_at asc`)
    .all(familyId)
    .map((row) => rowToApi(table, row));

  res.json(rows);
});

app.put("/api/:table/:id", (req, res) => {
  const table = requireTable(req.params.table);
  const item = sanitizeBody(table, req.body, req.params.id);
  const saved = upsertLastWriteWins(table, item);
  res.json(rowToApi(table, saved));
});

app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(error.statusCode || 500).json({
    error: error.message || "Błąd serwera.",
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Rodzinna Lista Zakupów API działa na porcie ${port}`);
  console.log(`SQLite: ${dbPath}`);
});

function initializeDatabase() {
  db.exec(`
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
      instructions text not null default '',
      base_servings integer not null default 4,
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
  `);
}

function requireTable(table) {
  if (!Object.hasOwn(tables, table)) {
    const error = new Error("Nieznana tabela.");
    error.statusCode = 404;
    throw error;
  }
  return table;
}

function sanitizeBody(table, body, id) {
  const config = tables[table];
  const item = {};

  for (const column of config.columns) {
    if (column === "id") {
      item.id = id;
      continue;
    }

    if (!Object.hasOwn(body, column)) {
      item[column] = null;
      continue;
    }

    if (config.boolColumns.includes(column)) {
      item[column] = boolToInt(body[column]);
    } else if (config.numberColumns.includes(column)) {
      item[column] = Number(body[column] || 0);
    } else {
      item[column] = body[column] ?? null;
    }
  }

  item.created_at = item.created_at || new Date().toISOString();
  item.updated_at = item.updated_at || item.created_at;

  if (table === "families") {
    item.family_id = item.family_id || item.id;
    item.code = (item.code || "").toString().toUpperCase();
  }

  return item;
}

function upsertLastWriteWins(table, item) {
  const existing = db.prepare(`select * from ${table} where id = ?`).get(item.id);

  if (existing) {
    const incomingTime = Date.parse(item.updated_at || "");
    const existingTime = Date.parse(existing.updated_at || "");

    if (!Number.isNaN(existingTime) && incomingTime < existingTime) {
      return existing;
    }

    updateRow(table, item);
    return db.prepare(`select * from ${table} where id = ?`).get(item.id);
  }

  insertRow(table, item);
  return db.prepare(`select * from ${table} where id = ?`).get(item.id);
}

function insertRow(table, item) {
  const columns = tables[table].columns;
  const placeholders = columns.map((column) => `@${column}`).join(", ");
  db.prepare(
    `insert into ${table} (${columns.join(", ")}) values (${placeholders})`,
  ).run(item);
}

function updateRow(table, item) {
  const columns = tables[table].columns.filter((column) => column !== "id");
  const assignments = columns.map((column) => `${column} = @${column}`).join(", ");
  db.prepare(`update ${table} set ${assignments} where id = @id`).run(item);
}

function rowToApi(table, row) {
  const config = tables[table];
  const item = { ...row };

  for (const column of config.boolColumns) {
    item[column] = Boolean(item[column]);
  }

  for (const column of config.numberColumns) {
    item[column] = Number(item[column] || 0);
  }

  return item;
}

function boolToInt(value) {
  if (typeof value === "boolean") {
    return value ? 1 : 0;
  }
  if (typeof value === "number") {
    return value === 0 ? 0 : 1;
  }
  if (typeof value === "string") {
    return value === "true" || value === "1" ? 1 : 0;
  }
  return 0;
}
