const schemaVersion = 5;

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
      "recipe_category",
      "instructions",
      "base_servings",
      "calories_per_serving",
      "protein_per_serving",
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
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["daily_calories", "daily_protein"],
  },
  nutrition_entries: {
    columns: [
      "id",
      "family_id",
      "member_id",
      "entry_date",
      "calories",
      "protein",
      "note",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["calories", "protein"],
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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request, env) {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders });
      }
      return await handleRequest(request, env);
    } catch (error) {
      const status = error instanceof ApiError ? error.statusCode : 500;
      console.error(
        JSON.stringify({
          message: error?.message ?? "Unknown error",
          stack: error?.stack,
        }),
      );
      return json({ error: error?.message || "Blad serwera." }, status);
    }
  },
};

async function handleRequest(request, env) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (request.method === "GET" && path === "/") {
    return json({
      name: "Rodzinna Lista Zakupow API",
      status: "ok",
      schemaVersion,
      health: "/api/health",
    });
  }

  if (request.method === "GET" && path === "/api/health") {
    return health(env);
  }

  const familyCodeMatch = path.match(/^\/api\/families\/code\/([^/]+)$/);
  if (request.method === "GET" && familyCodeMatch) {
    return familyByCode(env, decodeURIComponent(familyCodeMatch[1]));
  }

  const collectionMatch = path.match(/^\/api\/([^/]+)$/);
  if (request.method === "GET" && collectionMatch) {
    return listRows(env, collectionMatch[1], url.searchParams);
  }

  const itemMatch = path.match(/^\/api\/([^/]+)\/([^/]+)$/);
  if (request.method === "PUT" && itemMatch) {
    return upsertRow(env, itemMatch[1], decodeURIComponent(itemMatch[2]), request);
  }

  throw new ApiError("Nieznana sciezka.", 404);
}

async function health(env) {
  const { results } = await env.DB.prepare(
    "select name from sqlite_master where type = 'table' order by name",
  ).all();
  const existingTables = results.map((row) => row.name);
  const expectedTables = Object.keys(tables);
  const missingTables = expectedTables.filter(
    (table) => !existingTables.includes(table),
  );

  return json({
    ok: missingTables.length === 0,
    schemaVersion,
    database: "rodzinna-lista-zakupow",
    expectedTables,
    tables: existingTables.filter((table) => expectedTables.includes(table)),
    missingTables,
  });
}

async function familyByCode(env, code) {
  const row = await env.DB.prepare(
    "select * from families where upper(code) = upper(?) and is_deleted = 0 limit 1",
  )
    .bind(code)
    .first();

  if (!row) {
    throw new ApiError("Rodzina o takim kodzie nie istnieje.", 404);
  }

  return json(rowToApi("families", row));
}

async function listRows(env, tableName, searchParams) {
  const table = requireTable(tableName);
  const familyId = searchParams.get("familyId")?.trim();

  if (!familyId) {
    throw new ApiError("Brakuje parametru familyId.", 400);
  }

  const { results } = await env.DB.prepare(
    `select * from ${table} where family_id = ? order by updated_at asc`,
  )
    .bind(familyId)
    .all();

  return json(results.map((row) => rowToApi(table, row)));
}

async function upsertRow(env, tableName, id, request) {
  const table = requireTable(tableName);
  const body = await request.json();
  const item = sanitizeBody(table, body, id);
  const saved = await upsertLastWriteWins(env, table, item);

  return json(rowToApi(table, saved));
}

async function upsertLastWriteWins(env, table, item) {
  const existing = await env.DB.prepare(`select * from ${table} where id = ?`)
    .bind(item.id)
    .first();

  if (existing) {
    const incomingTime = Date.parse(item.updated_at || "");
    const existingTime = Date.parse(existing.updated_at || "");

    if (!Number.isNaN(existingTime) && incomingTime < existingTime) {
      return existing;
    }

    await updateRow(env, table, item);
    return env.DB.prepare(`select * from ${table} where id = ?`)
      .bind(item.id)
      .first();
  }

  await insertRow(env, table, item);
  return env.DB.prepare(`select * from ${table} where id = ?`)
    .bind(item.id)
    .first();
}

async function insertRow(env, table, item) {
  const columns = tables[table].columns;
  const placeholders = columns.map(() => "?").join(", ");
  const values = columns.map((column) => item[column]);

  await env.DB.prepare(
    `insert into ${table} (${columns.join(", ")}) values (${placeholders})`,
  )
    .bind(...values)
    .run();
}

async function updateRow(env, table, item) {
  const columns = tables[table].columns.filter((column) => column !== "id");
  const assignments = columns.map((column) => `${column} = ?`).join(", ");
  const values = columns.map((column) => item[column]);

  await env.DB.prepare(`update ${table} set ${assignments} where id = ?`)
    .bind(...values, item.id)
    .run();
}

function requireTable(table) {
  if (!hasOwn(tables, table)) {
    throw new ApiError("Nieznana tabela.", 404);
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

    if (!hasOwn(body, column)) {
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
  if (column === "parent_recipe_id" || column === "member_id") {
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
  if (column === "items_json") {
    return "[]";
  }
  if (column === "recipe_ids") {
    return "";
  }
  if (column === "created_at" || column === "updated_at") {
    return new Date().toISOString();
  }
  if (column === "family_id" && table === "families") {
    return null;
  }
  return "";
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

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

class ApiError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = "ApiError";
    this.statusCode = statusCode;
  }
}
