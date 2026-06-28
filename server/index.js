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
      "category",
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
      "recipe_category",
      "instructions",
      "base_servings",
      "calories_per_serving",
      "protein_per_serving",
      "fat_per_serving",
      "carbs_per_serving",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: [
      "base_servings",
      "calories_per_serving",
      "protein_per_serving",
      "fat_per_serving",
      "carbs_per_serving",
    ],
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
  nutrition_goals: {
    columns: [
      "id",
      "family_id",
      "member_id",
      "daily_calories",
      "daily_protein",
      "daily_fat",
      "daily_carbs",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: [
      "daily_calories",
      "daily_protein",
      "daily_fat",
      "daily_carbs",
    ],
  },
  nutrition_entries: {
    columns: [
      "id",
      "family_id",
      "member_id",
      "entry_date",
      "calories",
      "protein",
      "fat",
      "carbs",
      "note",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["calories", "protein", "fat", "carbs"],
  },
  training_entries: {
    columns: [
      "id",
      "family_id",
      "member_id",
      "training_date",
      "activity",
      "duration_minutes",
      "note",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["duration_minutes"],
  },
  favorite_products: {
    columns: [
      "id",
      "family_id",
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
  receipts: {
    columns: [
      "id",
      "family_id",
      "store_name",
      "purchased_at",
      "total",
      "raw_text",
      "image_data",
      "image_mime_type",
      "items_json",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["total"],
  },
};

initializeDatabase();

app.use(cors());
app.use(express.json({ limit: "12mb" }));
app.use(morgan("tiny"));

app.get("/", (_req, res) => {
  res.json({
    name: "Rodzinna Lista Zakupów API",
    status: "ok",
    schemaVersion: 7,
    health: "/api/health",
  });
});

app.get("/api/health", (_req, res) => {
  const existingTables = db
    .prepare("select name from sqlite_master where type = 'table' order by name")
    .all()
    .map((row) => row.name);
  const expectedTables = Object.keys(tables);
  const missingTables = expectedTables.filter((table) => !existingTables.includes(table));

  res.json({
    ok: missingTables.length === 0,
    schemaVersion: 7,
    database: path.basename(dbPath),
    dbPath,
    expectedTables,
    tables: existingTables.filter((table) => expectedTables.includes(table)),
    missingTables,
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

app.post("/api/ai/recipe-scan", async (req, res, next) => {
  try {
    const result = await scanRecipeFromRequest({
      body: req.body,
      apiKey: process.env.OPENAI_API_KEY,
      model: process.env.OPENAI_RECIPE_MODEL || "gpt-4.1-mini",
    });
    res.json(result);
  } catch (error) {
    next(error);
  }
});

app.post("/api/ai/receipt-scan", async (req, res, next) => {
  try {
    const result = await scanReceiptFromRequest({
      body: req.body,
      apiKey: process.env.OPENAI_API_KEY,
      model: process.env.OPENAI_RECEIPT_MODEL || "gpt-4.1-mini",
    });
    res.json(result);
  } catch (error) {
    next(error);
  }
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
      fat_per_serving real not null default 0,
      carbs_per_serving real not null default 0,
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
      daily_fat real not null default 0,
      daily_carbs real not null default 0,
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
      fat real not null default 0,
      carbs real not null default 0,
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
  `);

  ensureColumn("recipes", "recipe_category", "text not null default 'Obiady'");
  ensureColumn("recipes", "calories_per_serving", "integer not null default 0");
  ensureColumn("recipes", "protein_per_serving", "real not null default 0");
  ensureColumn("recipes", "fat_per_serving", "real not null default 0");
  ensureColumn("recipes", "carbs_per_serving", "real not null default 0");
  ensureColumn("shopping_items", "category", "text");
  ensureColumn("nutrition_goals", "daily_fat", "real not null default 0");
  ensureColumn("nutrition_goals", "daily_carbs", "real not null default 0");
  ensureColumn("nutrition_entries", "fat", "real not null default 0");
  ensureColumn("nutrition_entries", "carbs", "real not null default 0");
  ensureColumn("receipts", "image_data", "text");
  ensureColumn("receipts", "image_mime_type", "text");
}

function ensureColumn(table, column, definition) {
  const columns = db.prepare(`pragma table_info(${table})`).all();
  if (columns.some((item) => item.name === column)) {
    return;
  }
  db.prepare(`alter table ${table} add column ${column} ${definition}`).run();
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
      item[column] = defaultMissingValue(table, config, column);
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

function defaultMissingValue(table, config, column) {
  if (config.boolColumns.includes(column)) {
    return 0;
  }
  if (config.numberColumns.includes(column)) {
    if (column === "base_servings" || column === "servings") {
      return 1;
    }
    if (column === "quantity") {
      return 1;
    }
    return 0;
  }
  if (
    column === "parent_recipe_id" ||
    column === "member_id" ||
    column === "category"
  ) {
    return null;
  }
  if (column === "recipe_category") {
    return "Obiady";
  }
  if (column === "unit") {
    return "szt.";
  }
  if (column === "activity") {
    return "Trening";
  }
  if (column === "store_name") {
    return "Sklep";
  }
  if (column === "items_json" || column === "recipe_ids") {
    return "[]";
  }
  if (column === "created_at" || column === "updated_at") {
    return new Date().toISOString();
  }
  if (column === "family_id" && table === "families") {
    return null;
  }
  return "";
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

async function scanReceiptFromRequest({ body, apiKey, model }) {
  const text = cleanText(body?.text);
  const imageData = cleanText(body?.imageData);
  const imageMimeType = cleanText(body?.imageMimeType) || "image/jpeg";

  if (!text && !imageData) {
    throw httpError("Dodaj zdjęcie albo tekst paragonu.", 400);
  }

  if (apiKey) {
    try {
      return normalizeReceiptScanDraft(
        await scanReceiptWithOpenAi({
          apiKey,
          model,
          text,
          imageData,
          imageMimeType,
        }),
      );
    } catch (error) {
      if (!text) {
        throw error;
      }
      console.warn(
        "AI receipt scan failed, using text fallback:",
        error.message,
      );
    }
  }

  if (!text) {
    throw httpError(
      "AI nie jest jeszcze skonfigurowane. Ustaw OPENAI_API_KEY na serwerze.",
      503,
    );
  }

  return normalizeReceiptScanDraft(parseReceiptTextFallback(text));
}

async function scanReceiptWithOpenAi({
  apiKey,
  model,
  text,
  imageData,
  imageMimeType,
}) {
  const content = [
    {
      type: "input_text",
      text: [
        "Odczytaj polski paragon ze zdjęcia lub tekstu OCR.",
        "Zwróć sklep, kwotę razem i listę produktów. Pomijaj NIP, numer paragonu, VAT, płatność, kody i losowe numery.",
        "Dla produktów podaj nazwę, ilość, jednostkę i cenę końcową z paragonu. Jeśli czegoś nie ma, użyj rozsądnego minimum: ilość 1, jednostka szt., cena 0.",
        text ? `Tekst OCR/użytkownika:\n${text}` : "",
      ]
        .filter(Boolean)
        .join("\n"),
    },
  ];

  if (imageData) {
    content.push({
      type: "input_image",
      image_url: `data:${imageMimeType};base64,${imageData}`,
    });
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [{ role: "user", content }],
      max_output_tokens: 1800,
      text: {
        format: {
          type: "json_schema",
          name: "receipt_scan",
          strict: true,
          schema: receiptScanJsonSchema(),
        },
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw httpError(
      payload?.error?.message || `OpenAI error ${response.status}`,
      response.status,
    );
  }

  const outputText = extractOpenAiOutputText(payload);
  if (!outputText) {
    throw httpError("AI nie zwróciło paragonu.", 502);
  }
  return JSON.parse(outputText);
}

function receiptScanJsonSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["storeName", "total", "items"],
    properties: {
      storeName: { type: "string" },
      total: { type: "number", minimum: 0 },
      items: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["name", "quantity", "unit", "price"],
          properties: {
            name: { type: "string" },
            quantity: { type: "number", minimum: 0 },
            unit: { type: "string" },
            price: { type: "number", minimum: 0 },
          },
        },
      },
    },
  };
}

function parseReceiptTextFallback(text) {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean);
  const items = [];
  let total = 0;

  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    const lower = normalizeForReceiptSearch(line);
    const price = lastReceiptPrice(line);
    if (isReceiptTotalLine(lower)) {
      total = price?.value || nearbyReceiptPrice(lines, index)?.value || total;
      continue;
    }
    if (!price || shouldSkipReceiptLine(lower)) {
      continue;
    }
    const item = receiptItemFromLine(line, price, lines[index - 1]);
    if (
      item &&
      !items.some(
        (existing) =>
          normalizeForReceiptSearch(existing.name) ===
            normalizeForReceiptSearch(item.name) && existing.price === item.price,
      )
    ) {
      items.push(item);
    }
  }

  return {
    storeName: detectReceiptStoreName(lines) || "Sklep",
    total: total || items.reduce((sum, item) => sum + item.price, 0),
    items,
  };
}

function receiptItemFromLine(line, price, previousLine) {
  let beforePrice = line.slice(0, price.start).trim();
  if (
    previousLine &&
    !lastReceiptPrice(previousLine) &&
    isReceiptProductName(previousLine) &&
    (lineHasOnlyReceiptPrice(line) || lineLooksLikeReceiptPriceContinuation(line))
  ) {
    beforePrice = `${previousLine} ${beforePrice}`;
  }

  const parsedQuantity = receiptQuantityFromLine(beforePrice);
  const name = beforePrice
    .replace(receiptUnitPricePattern, " ")
    .replace(receiptPricePattern, " ")
    .replace(receiptQuantityPattern, " ")
    .replace(/\b\d+(?:[,.]\d+)?\s*x\b/gi, " ")
    .replace(/\bx\s*\d+(?:[,. ]\d{2})\b/gi, " ")
    .replace(/\bx\b/gi, " ")
    .replace(/\bVAT\s*[A-Z]\b/gi, " ")
    .replace(/\b[A-Z]\b$/g, " ")
    .replace(/\b(kg|g|l|ml|szt|szt\.|op|opak)\b$/gi, " ")
    .replace(/[*#:;]/g, " ")
    .replace(/\b\d{5,}\b/g, " ")
    .replace(/^[0-9]{2,}\s+/, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (!isReceiptProductName(name)) {
    return null;
  }

  return {
    name: titleCaseProduct(name),
    quantity: parsedQuantity.quantity,
    unit: normalizeUnit(parsedQuantity.unit),
    price: price.value,
  };
}

function normalizeReceiptScanDraft(value) {
  const items = Array.isArray(value.items)
    ? value.items
        .map((item) => ({
          name: cleanText(item?.name),
          quantity: Math.max(0, Number(item?.quantity || 1)),
          unit: normalizeUnit(cleanText(item?.unit) || "szt."),
          price: Math.max(0, Number(item?.price || 0)),
        }))
        .filter((item) => item.name && item.quantity > 0)
    : [];
  const sum = items.reduce((total, item) => total + item.price, 0);
  return {
    storeName: cleanText(value.storeName) || "Sklep",
    total: Math.max(0, Number(value.total || 0)) || sum,
    items,
  };
}

async function scanRecipeFromRequest({ body, apiKey, model }) {
  const text = cleanText(body?.text);
  const imageData = cleanText(body?.imageData);
  const imageMimeType = cleanText(body?.imageMimeType) || "image/jpeg";

  if (!text && !imageData) {
    throw httpError("Dodaj zdjęcie albo tekst przepisu.", 400);
  }

  if (apiKey) {
    try {
      return normalizeRecipeScanDraft(
        await scanRecipeWithOpenAi({
          apiKey,
          model,
          text,
          imageData,
          imageMimeType,
        }),
      );
    } catch (error) {
      if (!text) {
        throw error;
      }
      console.warn("AI recipe scan failed, using text fallback:", error.message);
    }
  }

  if (!text) {
    throw httpError(
      "AI nie jest jeszcze skonfigurowane. Ustaw OPENAI_API_KEY na serwerze.",
      503,
    );
  }

  return normalizeRecipeScanDraft(parseRecipeTextFallback(text));
}

async function scanRecipeWithOpenAi({ apiKey, model, text, imageData, imageMimeType }) {
  const content = [
    {
      type: "input_text",
      text: [
        "Odczytaj polski przepis kulinarny ze zdjęcia lub tekstu.",
        "Zwróć tylko dane przepisu. Nie zgaduj agresywnie: jeśli kcal, białka, tłuszczu albo węglowodanów nie ma, ustaw 0.",
        "Kategorie dozwolone: Śniadania, Obiady, Kolacje, Przekąski, Desery, Napoje, Anna, Kaja, Maciej, Tomek.",
        "Normalizuj składniki do pól: nazwa, ilość, jednostka. Instrukcję zapisz po polsku.",
        text ? `Tekst OCR/użytkownika:\n${text}` : "",
      ]
        .filter(Boolean)
        .join("\n"),
    },
  ];

  if (imageData) {
    content.push({
      type: "input_image",
      image_url: `data:${imageMimeType};base64,${imageData}`,
    });
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [{ role: "user", content }],
      max_output_tokens: 1800,
      text: {
        format: {
          type: "json_schema",
          name: "recipe_scan",
          strict: true,
          schema: recipeScanJsonSchema(),
        },
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw httpError(
      payload?.error?.message || `OpenAI error ${response.status}`,
      response.status,
    );
  }

  const outputText = extractOpenAiOutputText(payload);
  if (!outputText) {
    throw httpError("AI nie zwróciło przepisu.", 502);
  }
  return JSON.parse(outputText);
}

function recipeScanJsonSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "name",
      "category",
      "instructions",
      "baseServings",
      "caloriesPerServing",
      "proteinPerServing",
      "fatPerServing",
      "carbsPerServing",
      "ingredients",
    ],
    properties: {
      name: { type: "string" },
      category: {
        type: "string",
        enum: [
          "Śniadania",
          "Obiady",
          "Kolacje",
          "Przekąski",
          "Desery",
          "Napoje",
          "Anna",
          "Kaja",
          "Maciej",
          "Tomek",
        ],
      },
      instructions: { type: "string" },
      baseServings: { type: "integer", minimum: 1 },
      caloriesPerServing: { type: "integer", minimum: 0 },
      proteinPerServing: { type: "number", minimum: 0 },
      fatPerServing: { type: "number", minimum: 0 },
      carbsPerServing: { type: "number", minimum: 0 },
      ingredients: {
        type: "array",
        minItems: 1,
        items: {
          type: "object",
          additionalProperties: false,
          required: ["name", "quantity", "unit"],
          properties: {
            name: { type: "string" },
            quantity: { type: "number", exclusiveMinimum: 0 },
            unit: { type: "string" },
          },
        },
      },
    },
  };
}

function extractOpenAiOutputText(payload) {
  if (typeof payload.output_text === "string") {
    return payload.output_text;
  }
  for (const item of payload.output || []) {
    for (const part of item.content || []) {
      if (part.type === "output_text" && typeof part.text === "string") {
        return part.text;
      }
    }
  }
  return "";
}

function parseRecipeTextFallback(text) {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const name =
    lines.find(
      (line) =>
        !isRecipeSectionHeader(line) &&
        !isServingLine(line) &&
        !parseIngredientLine(line),
    ) ||
    lines[0] ||
    "Nowy przepis";
  const baseServings = findServings(text);
  const ingredients = [];
  const instructionLines = [];
  let inIngredients = false;
  let inInstructions = false;

  for (const line of lines) {
    if (isIngredientsHeader(line)) {
      inIngredients = true;
      inInstructions = false;
      continue;
    }
    if (isInstructionsHeader(line)) {
      inIngredients = false;
      inInstructions = true;
      continue;
    }
    if (isServingLine(line)) {
      continue;
    }
    if (line === name) {
      continue;
    }

    const ingredient = parseIngredientLine(line);
    if ((inIngredients || ingredient) && ingredient && !inInstructions) {
      ingredients.push(ingredient);
      continue;
    }
    if (inInstructions || !ingredient) {
      instructionLines.push(line);
    }
  }

  return {
    name,
    category: guessRecipeCategory(text),
    instructions: instructionLines.join("\n").trim(),
    baseServings,
    caloriesPerServing: findNutrition(text, /(\d{2,5})\s*kcal/i),
    proteinPerServing: findNutrition(
      text,
      /(\d+(?:[,.]\d+)?)\s*g\s*(?:białka|bialka|protein)/i,
    ),
    fatPerServing: findNutrition(
      text,
      /(\d+(?:[,.]\d+)?)\s*g\s*(?:tłuszczu|tluszczu|tłuszcze|tluszcze|fat)/i,
    ),
    carbsPerServing: findNutrition(
      text,
      /(\d+(?:[,.]\d+)?)\s*g\s*(?:węglowodanów|weglowodanow|węgle|wegle|carbs|carbohydrates)/i,
    ),
    ingredients,
  };
}

function parseIngredientLine(line) {
  const cleaned = line
    .replace(/^[\s\-*•]+/, "")
    .replace(/\s+/g, " ")
    .trim();
  const match = cleaned.match(
    /^(.+?)\s+(\d+(?:[,.]\d+)?|\d+\/\d+)\s*(g|kg|ml|l|szt\.?|łyżka|łyżki|łyżeczka|łyżeczki|szklanka|opak\.?|puszka|ząbek|garść)?$/i,
  );
  const reverseMatch = cleaned.match(
    /^(\d+(?:[,.]\d+)?|\d+\/\d+)\s*(g|kg|ml|l|szt\.?|łyżka|łyżki|łyżeczka|łyżeczki|szklanka|opak\.?|puszka|ząbek|garść)?\s+(.+)$/i,
  );

  const source = match
    ? { name: match[1], quantity: match[2], unit: match[3] }
    : reverseMatch
    ? { name: reverseMatch[3], quantity: reverseMatch[1], unit: reverseMatch[2] }
    : null;
  if (!source) {
    return null;
  }
  const quantity = parseQuantity(source.quantity);
  const name = source.name.trim();
  if (!name || quantity <= 0 || /^(porcj|osob)/i.test(name)) {
    return null;
  }
  return {
    name,
    quantity,
    unit: normalizeUnit(source.unit || "szt."),
  };
}

function normalizeRecipeScanDraft(value) {
  const ingredients = Array.isArray(value.ingredients)
    ? value.ingredients
        .map((item) => ({
          name: cleanText(item?.name),
          quantity: Number(item?.quantity || 0),
          unit: normalizeUnit(cleanText(item?.unit) || "szt."),
        }))
        .filter((item) => item.name && item.quantity > 0)
    : [];

  if (ingredients.length === 0) {
    throw httpError("Nie rozpoznano składników przepisu.", 422);
  }

  return {
    name: cleanText(value.name) || "Nowy przepis",
    category: allowedRecipeCategories().includes(cleanText(value.category))
      ? cleanText(value.category)
      : "Obiady",
    instructions: cleanText(value.instructions),
    baseServings: Math.max(1, Math.round(Number(value.baseServings || 4))),
    caloriesPerServing: Math.max(
      0,
      Math.round(Number(value.caloriesPerServing || 0)),
    ),
    proteinPerServing: Math.max(0, Number(value.proteinPerServing || 0)),
    fatPerServing: Math.max(0, Number(value.fatPerServing || 0)),
    carbsPerServing: Math.max(0, Number(value.carbsPerServing || 0)),
    ingredients,
  };
}

function allowedRecipeCategories() {
  return [
    "Śniadania",
    "Obiady",
    "Kolacje",
    "Przekąski",
    "Desery",
    "Napoje",
    "Anna",
    "Kaja",
    "Maciej",
    "Tomek",
  ];
}

function isRecipeSectionHeader(line) {
  return isIngredientsHeader(line) || isInstructionsHeader(line);
}

function isIngredientsHeader(line) {
  return /^składniki:?$/i.test(line) || /^skladniki:?$/i.test(line);
}

function isInstructionsHeader(line) {
  return /^(przygotowanie|wykonanie|sposób przygotowania|sposob przygotowania):?$/i.test(line);
}

function isServingLine(line) {
  return /^\d{1,2}\s*(?:porcj|osob)/i.test(line);
}

function guessRecipeCategory(text) {
  const value = text.toLowerCase();
  if (/śniad|sniad|owsianka|jajecznica/.test(value)) return "Śniadania";
  if (/deser|ciasto|lody|tort|naleśniki/.test(value)) return "Desery";
  if (/koktajl|napój|napoj|lemoniada/.test(value)) return "Napoje";
  if (/kolacj/.test(value)) return "Kolacje";
  if (/przekąsk|przekask/.test(value)) return "Przekąski";
  return "Obiady";
}

function findServings(text) {
  const match = text.match(/(\d{1,2})\s*(?:porcj|osob)/i);
  return match ? Math.max(1, Number(match[1])) : 4;
}

function findNutrition(text, pattern) {
  const match = text.match(pattern);
  return match ? Number(match[1].replace(",", ".")) || 0 : 0;
}

function parseQuantity(value) {
  const normalized = value.replace(",", ".");
  const fraction = normalized.match(/^(\d+)\/(\d+)$/);
  if (fraction) {
    return Number(fraction[1]) / Number(fraction[2]);
  }
  return Number(normalized) || 0;
}

function normalizeUnit(value) {
  const unit = cleanText(value).toLowerCase().replace(/\.$/, "");
  const aliases = {
    szt: "szt.",
    sztuka: "szt.",
    sztuki: "szt.",
    lyzka: "łyżka",
    lyzki: "łyżka",
    "łyżki": "łyżka",
    lyzeczka: "łyżeczka",
    lyzeczki: "łyżeczka",
    "łyżeczki": "łyżeczka",
    opak: "opak.",
    op: "opak.",
    zabek: "ząbek",
    zabki: "ząbek",
  };
  return aliases[unit] || unit || "szt.";
}

function detectReceiptStoreName(lines) {
  const knownStores = {
    biedronka: "Biedronka",
    lidl: "Lidl",
    kaufland: "Kaufland",
    aldi: "Aldi",
    carrefour: "Carrefour",
    auchan: "Auchan",
    dino: "Dino",
    zabka: "Żabka",
    netto: "Netto",
    stokrotka: "Stokrotka",
    rossmann: "Rossmann",
    hebe: "Hebe",
    pepco: "Pepco",
    action: "Action",
  };
  for (const line of lines.slice(0, 14)) {
    const normalized = normalizeForReceiptSearch(line);
    for (const [key, value] of Object.entries(knownStores)) {
      if (normalized.includes(key)) {
        return value;
      }
    }
  }
  for (const line of lines.slice(0, 8)) {
    const candidate = line
      .replace(/[^A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż0-9 &.-]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    const lower = normalizeForReceiptSearch(candidate);
    if (
      candidate.length >= 3 &&
      candidate.length <= 36 &&
      receiptLetterPattern.test(candidate) &&
      !shouldSkipReceiptLine(lower) &&
      !isReceiptTotalLine(lower) &&
      !/\d{4,}/.test(candidate)
    ) {
      return titleCase(candidate);
    }
  }
  return "";
}

function isReceiptProductName(value) {
  const name = cleanText(value);
  if (name.length < 2 || !receiptLetterPattern.test(name)) {
    return false;
  }
  if (/^\d+$/.test(name) || /\b\d{8,}\b/.test(name)) {
    return false;
  }
  const lower = normalizeForReceiptSearch(name);
  return !shouldSkipReceiptLine(lower) && !isReceiptTotalLine(lower);
}

function isReceiptTotalLine(line) {
  return (
    line.includes("suma") ||
    line.includes("razem") ||
    line.includes("lacznie") ||
    line.includes("do zaplaty") ||
    line.includes("naleznosc") ||
    line.includes("kwota") ||
    line.includes("total")
  );
}

function shouldSkipReceiptLine(line) {
  return [
    "paragon",
    "fiskalny",
    "nip",
    "sprzedaz",
    "podatek",
    "vat",
    "kasa",
    "kasjer",
    "terminal",
    "platnosc",
    "karta",
    "gotowka",
    "reszta",
    "data",
    "godz",
    "adres",
    "nr wydruku",
    "nr paragonu",
    "numer",
    "www",
    "bon",
    "rabat",
    "wydruk",
    "transakcja",
    "autoryzacja",
    "dziekujemy",
  ].some((word) => line.includes(word));
}

function nearbyReceiptPrice(lines, index) {
  for (const offset of [0, 1, -1, 2]) {
    const nextIndex = index + offset;
    if (nextIndex < 0 || nextIndex >= lines.length) {
      continue;
    }
    const price = lastReceiptPrice(lines[nextIndex]);
    if (price) {
      return price;
    }
  }
  return null;
}

function lastReceiptPrice(line) {
  const matches = [...line.matchAll(receiptPricePattern)];
  if (matches.length === 0) {
    return null;
  }
  const match = matches[matches.length - 1];
  return {
    start: match.index || 0,
    value: Number(`${match[1]}.${match[3]}`) || 0,
  };
}

function lineHasOnlyReceiptPrice(line) {
  return stripReceiptPriceNoise(line).length === 0;
}

function lineLooksLikeReceiptPriceContinuation(line) {
  const stripped = stripReceiptPriceNoise(line)
    .replace(receiptQuantityPattern, " ")
    .replace(/\b\d+(?:[,.]\d+)?\s*x\b/gi, " ")
    .replace(/\bx\b/gi, " ")
    .replace(/\b(kg|g|l|ml|szt|op|opak)\b/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
  return stripped.length === 0;
}

function stripReceiptPriceNoise(line) {
  return line
    .replace(receiptPricePattern, " ")
    .replace(/\b(zł|zl|pln)\b/gi, " ")
    .replace(/\b[A-Z]\b/g, " ")
    .replace(/[\s:;.-]+/g, " ")
    .trim();
}

function receiptQuantityFromLine(line) {
  const quantityMatch = line.match(receiptQuantityPattern);
  if (quantityMatch) {
    return {
      quantity: Number(quantityMatch[1].replace(",", ".")) || 1,
      unit: quantityMatch[2] || "szt.",
    };
  }
  const multiplierMatch = line.match(/\b(\d+(?:[,.]\d+)?)\s*x\b/i);
  if (multiplierMatch) {
    return {
      quantity: Number(multiplierMatch[1].replace(",", ".")) || 1,
      unit: "szt.",
    };
  }
  return { quantity: 1, unit: "szt." };
}

function normalizeForReceiptSearch(value) {
  return cleanText(value)
    .toLowerCase()
    .replaceAll("ą", "a")
    .replaceAll("ć", "c")
    .replaceAll("ę", "e")
    .replaceAll("ł", "l")
    .replaceAll("ń", "n")
    .replaceAll("ó", "o")
    .replaceAll("ś", "s")
    .replaceAll("ź", "z")
    .replaceAll("ż", "z")
    .replace(/[^a-z0-9,. ]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function titleCase(value) {
  return cleanText(value)
    .split(" ")
    .filter(Boolean)
    .map((part) =>
      part.length <= 2 && part === part.toUpperCase()
        ? part
        : part[0].toUpperCase() + part.slice(1).toLowerCase(),
    )
    .join(" ");
}

function titleCaseProduct(value) {
  return value === value.toUpperCase() ? titleCase(value) : value;
}

const receiptLetterPattern = /[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]/;
const receiptPricePattern =
  /(?<!\d)(\d{1,5})\s*([,.\-:]|\s+)\s*(\d{2})(?!\d)(?:\s*(?:zł|zl|pln|[A-Z]))?/gi;
const receiptUnitPricePattern =
  /\b\d{1,5}(?:[,.]\d{2})\s*\/\s*(kg|g|l|ml|szt)\b/gi;
const receiptQuantityPattern =
  /(\d+(?:[,.]\d+)?)\s*(kg|g|l|ml|szt|szt\.|op|opak)\.?/i;

function cleanText(value) {
  return (value ?? "").toString().trim();
}

function httpError(message, statusCode) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}
