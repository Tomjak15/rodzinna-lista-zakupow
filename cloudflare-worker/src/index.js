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
  "Access-Control-Allow-Methods": "GET, PUT, POST, OPTIONS",
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

  if (request.method === "POST" && path === "/api/ai/recipe-scan") {
    return scanRecipe(request, env);
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

async function scanRecipe(request, env) {
  const body = await request.json();
  const result = await scanRecipeFromRequest({
    body,
    apiKey: env.OPENAI_API_KEY,
    model: env.OPENAI_RECIPE_MODEL || "gpt-4.1-mini",
  });
  return json(result);
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

async function scanRecipeFromRequest({ body, apiKey, model }) {
  const text = cleanText(body?.text);
  const imageData = cleanText(body?.imageData);
  const imageMimeType = cleanText(body?.imageMimeType) || "image/jpeg";

  if (!text && !imageData) {
    throw new ApiError("Dodaj zdjęcie albo tekst przepisu.", 400);
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
    throw new ApiError(
      "AI nie jest jeszcze skonfigurowane. Ustaw OPENAI_API_KEY w Cloudflare.",
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
        "Zwróć tylko dane przepisu. Nie zgaduj agresywnie: jeśli kcal/białka nie ma, ustaw 0.",
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
    throw new ApiError(
      payload?.error?.message || `OpenAI error ${response.status}`,
      response.status,
    );
  }

  const outputText = extractOpenAiOutputText(payload);
  if (!outputText) {
    throw new ApiError("AI nie zwróciło przepisu.", 502);
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
      "ingredients",
    ],
    properties: {
      name: { type: "string" },
      category: {
        type: "string",
        enum: allowedRecipeCategories(),
      },
      instructions: { type: "string" },
      baseServings: { type: "integer", minimum: 1 },
      caloriesPerServing: { type: "integer", minimum: 0 },
      proteinPerServing: { type: "number", minimum: 0 },
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
    proteinPerServing: findNutrition(text, /(\d+(?:[,.]\d+)?)\s*g\s*(?:białka|bialka|protein)/i),
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
    throw new ApiError("Nie rozpoznano składników przepisu.", 422);
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

function cleanText(value) {
  return (value ?? "").toString().trim();
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
