const schemaVersion = 9;
const defaultWorkersAiTextModel = "@cf/mistralai/mistral-small-3.1-24b-instruct";
const defaultWorkersAiVisionModel = "@cf/meta/llama-3.2-11b-vision-instruct";
const fallbackWorkersAiVisionModel = "@cf/llava-hf/llava-1.5-7b-hf";

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
      "daily_steps",
      "daily_training_minutes",
      "weekly_training_minutes",
      "weekly_training_count",
      "weekly_steps",
      "weekly_distance_km",
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
      "daily_steps",
      "daily_training_minutes",
      "weekly_training_minutes",
      "weekly_training_count",
      "weekly_steps",
      "weekly_distance_km",
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
      "meal_type",
      "is_cheat_meal",
      "image_data",
      "image_mime_type",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_cheat_meal", "is_deleted"],
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
      "steps",
      "distance_km",
      "note",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
    boolColumns: ["is_deleted"],
    numberColumns: ["duration_minutes", "steps", "distance_km"],
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

  if (request.method === "POST" && path === "/api/ai/receipt-scan") {
    return scanReceipt(request, env);
  }

  if (request.method === "POST" && path === "/api/ai/product-category") {
    return classifyProductCategory(request, env);
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
    env,
    body,
    apiKey: env.OPENAI_API_KEY,
    model: env.OPENAI_RECIPE_MODEL || "gpt-4.1-mini",
    workersAi: env.AI,
    workersAiModel:
      env.CLOUDFLARE_RECIPE_VISION_MODEL || defaultWorkersAiVisionModel,
  });
  return json(result);
}

async function scanReceipt(request, env) {
  const body = await request.json();
  const result = await scanReceiptFromRequest({
    env,
    body,
    apiKey: env.OPENAI_API_KEY,
    model: env.OPENAI_RECEIPT_MODEL || "gpt-4.1-mini",
    workersAi: env.AI,
    workersAiModel:
      env.CLOUDFLARE_RECEIPT_VISION_MODEL || defaultWorkersAiVisionModel,
  });
  if (
    cleanText(body?.imageData) &&
    !cleanText(body?.text) &&
    Array.isArray(result.items) &&
    result.items.length === 0
  ) {
    return json({ storeName: "Sklep", total: 0, items: [] });
  }
  return json(result);
}

async function classifyProductCategory(request, env) {
  const body = await request.json();
  const name = cleanText(body?.name);
  if (!name) {
    throw new ApiError("Brakuje nazwy produktu.", 400);
  }

  const allowed = productCategoryNames();
  const fallback = localProductCategory(name);
  if (!env.AI) {
    return json({ category: fallback, source: "local" });
  }

  const familyHints = await loadFamilyScanHints(env, body?.familyId, {
    includeRecipeIngredients: false,
    includeReceipts: true,
  });
  const bodyHints = Array.isArray(body?.hints)
    ? body.hints.map(cleanText).filter(Boolean)
    : [];
  const hints = normalizeScanHints([...bodyHints, ...familyHints]).slice(0, 120);

  try {
    const outputText = await runWorkersAiTextJson({
      workersAi: env.AI,
      model: defaultWorkersAiTextModel,
      schema: productCategoryJsonSchema(),
      system:
        "Jestes klasyfikatorem polskich produktow na liscie zakupow. Odpowiadasz tylko poprawnym JSON.",
      prompt: [
        "Wybierz najlepsza kategorie dla produktu.",
        `Dozwolone kategorie: ${allowed.join(", ")}.`,
        "Nie klasyfikuj produktu po jednym mylacym slowie, jesli cala nazwa mowi cos innego.",
        "Przyklady:",
        "- platki kukurydziane -> Sypkie i makarony",
        "- maka kukurydziana -> Sypkie i makarony",
        "- chrupki kukurydziane -> Slodycze i przekaski",
        "- kukurydza w puszce -> Warzywa",
        "- papier toaletowy -> Chemia i dom",
        "- losowy gadzet -> Inne",
        hints.length ? `Znane produkty rodziny:\n${hints.join(", ")}` : "",
        `Produkt: ${name}`,
        'Zwroc tylko JSON w formacie: {"category":"Inne"}',
      ]
        .filter(Boolean)
        .join("\n"),
    });
    const parsed = parseAiJsonObject(outputText);
    const category = normalizeProductCategoryName(parsed?.category);
    if (allowed.includes(category)) {
      return json({ category, source: "ai" });
    }
  } catch (error) {
    console.warn("Workers AI product category failed:", error.message);
  }

  return json({ category: fallback, source: "local" });
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
  if (
    column === "parent_recipe_id" ||
    column === "member_id" ||
    column === "category" ||
    column === "image_data" ||
    column === "image_mime_type"
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
  if (column === "meal_type") {
    return "Posilek";
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

async function scanReceiptFromRequest({
  env,
  body,
  apiKey,
  model,
  workersAi,
  workersAiModel,
}) {
  const text = cleanText(body?.text);
  const imageData = cleanText(body?.imageData);
  const imageMimeType = cleanText(body?.imageMimeType) || "image/jpeg";
  const hints = await buildReceiptScanHints(env, body);

  if (!text && !imageData) {
    throw new ApiError("Dodaj zdjęcie albo tekst paragonu.", 400);
  }

  const receiptCandidates = [];

  if (apiKey) {
    try {
      const openAiResult = normalizeReceiptScanDraft(
        await scanReceiptWithOpenAi({
          apiKey,
          model,
          text,
          imageData,
          imageMimeType,
          hints,
        }),
        hints,
      );
      addReceiptCandidate(
        receiptCandidates,
        openAiResult,
        imageData ? "openai-image" : "openai",
      );
    } catch (error) {
      if (!text && !workersAi) {
        throw error;
      }
      console.warn(
        "AI receipt scan failed, using text fallback:",
        error.message,
      );
    }
  }

  const textFallback = text
    ? normalizeReceiptScanDraft(parseReceiptTextFallback(text), hints)
    : null;
  addReceiptCandidate(receiptCandidates, textFallback, "fallback");

  if (text && workersAi) {
    try {
      const aiTextResult = normalizeReceiptScanDraft(
        await scanReceiptTextWithWorkersAi({
          workersAi,
          text,
          hints,
        }),
        hints,
      );
      addReceiptCandidate(receiptCandidates, aiTextResult, "text-ai");
    } catch (error) {
      console.warn(
        "Workers AI receipt text scan failed, using fallback:",
        error.message,
      );
    }
  }

  if (imageData && workersAi) {
    try {
      const imageText = await readReceiptImageTextWithWorkersAi({
        workersAi,
        model: workersAiModel,
        text,
        imageData,
        imageMimeType,
      });
      if (imageText) {
        addReceiptCandidate(
          receiptCandidates,
          normalizeReceiptScanDraft(parseReceiptTextFallback(imageText), hints),
          "image-ocr-fallback",
        );
        try {
          const imageTextAiResult = normalizeReceiptScanDraft(
            await scanReceiptTextWithWorkersAi({
              workersAi,
              text: combineScanText(imageText, text),
              hints,
            }),
            hints,
          );
          addReceiptCandidate(
            receiptCandidates,
            imageTextAiResult,
            "image-ocr-ai",
          );
        } catch (error) {
          console.warn("Workers AI receipt OCR text parse failed:", error.message);
        }
      }
    } catch (error) {
      console.warn("Workers AI receipt image OCR failed:", error.message);
    }

    try {
      const imageAiResult = normalizeReceiptScanDraft(
        await scanReceiptWithWorkersAi({
          workersAi,
          model: workersAiModel,
          text,
          imageData,
          imageMimeType,
          hints,
        }),
        hints,
      );
      addReceiptCandidate(receiptCandidates, imageAiResult, "image-ai");
    } catch (error) {
      if (!text) {
        throw new ApiError(
          `Nie udalo sie odczytac zdjecia paragonu: ${error.message}`,
          error.statusCode || 502,
        );
      }
      console.warn(
        "Workers AI receipt scan failed, using text fallback:",
        error.message,
      );
    }
  }

  const bestCandidate = bestReceiptCandidate(receiptCandidates);
  if (bestCandidate) {
    return bestCandidate;
  }

  if (!text) {
    throw new ApiError(
      "Nie udalo sie odczytac zdjecia. Zrob wyrazniejsze zdjecie albo wpisz tekst recznie.",
      503,
    );
  }

  return textFallback || { storeName: "Sklep", total: 0, items: [] };
}

async function scanReceiptWithOpenAi({
  apiKey,
  model,
  text,
  imageData,
  imageMimeType,
  hints,
}) {
  const hintsText = scanHintsPrompt(hints, "Znane produkty w tej rodzinie");
  const content = [
    {
      type: "input_text",
      text: [
        "Jesli OCR jest podobny do produktu ze slownika, uzyj nazwy ze slownika. Slownik jest podpowiedzia, nie lista zamknieta.",
        receiptRulesPrompt(),
        receiptExamplesPrompt(),
        hintsText,
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
    throw new ApiError(
      payload?.error?.message || `OpenAI error ${response.status}`,
      response.status,
    );
  }

  const outputText = extractOpenAiOutputText(payload);
  if (!outputText) {
    throw new ApiError("AI nie zwróciło paragonu.", 502);
  }
  return JSON.parse(outputText);
}

async function scanReceiptTextWithWorkersAi({ workersAi, text, hints }) {
  const hintsText = scanHintsPrompt(hints, "Znane produkty w tej rodzinie");
  const outputText = await runWorkersAiTextJson({
    workersAi,
    model: defaultWorkersAiTextModel,
    schema: receiptScanJsonSchema(),
    system:
      "Jestes dokladnym parserem polskich paragonow. Odpowiadasz tylko poprawnym JSON.",
    prompt: [
      "Z tekstu OCR paragonu wyciagnij sklep, kwote razem i produkty.",
      "Pomin NIP, numer paragonu, VAT, platnosc, kody, losowe numery i reklamy.",
      "Jesli produkt ma tylko cene, ustaw ilosc 1 i jednostke szt.",
      "Jesli nazwa wyglada jak produkt ze slownika, popraw ja do nazwy ze slownika.",
      receiptRulesPrompt(),
      receiptExamplesPrompt(),
      hintsText,
      'Zwroc tylko JSON w formacie: {"storeName":"Sklep","total":0,"items":[{"name":"Produkt","quantity":1,"unit":"szt.","price":0}]}',
      `Tekst OCR:\n${text}`,
    ].filter(Boolean).join("\n"),
  });
  return parseAiJsonObject(outputText);
}

async function scanReceiptWithWorkersAi({
  workersAi,
  model,
  text,
  imageData,
  imageMimeType,
  hints,
}) {
  const hintsText = scanHintsPrompt(hints, "Znane produkty w tej rodzinie");
  return runWorkersAiVisionObject({
    workersAi,
    model,
    imageData,
    imageMimeType,
    system:
      "Jestes dokladnym parserem polskich paragonow. Odpowiadasz tylko poprawnym JSON.",
    prompt: [
      "Odczytaj paragon ze zdjecia. Tekst OCR traktuj tylko jako podpowiedz, bo moze byc pusty albo bledny.",
      "Pomin NIP, numer paragonu, VAT, platnosc, kody, losowe numery i reklamy.",
      "Znajdz sklep, kwote razem oraz produkty.",
      "Dla produktow podaj nazwe, ilosc, jednostke i cene koncowa z paragonu.",
      "Jesli ilosci nie widac, ustaw 1 i jednostke szt.",
      "Jesli nazwa wyglada jak produkt ze slownika, popraw ja do nazwy ze slownika.",
      receiptRulesPrompt(),
      receiptExamplesPrompt(),
      hintsText,
      'Zwroc tylko JSON w formacie: {"storeName":"Sklep","total":0,"items":[{"name":"Produkt","quantity":1,"unit":"szt.","price":0}]}',
      text ? `Tekst OCR/uzytkownika:\n${text}` : "",
    ]
      .filter(Boolean)
      .join("\n"),
  });
}

async function readReceiptImageTextWithWorkersAi({
  workersAi,
  model,
  text,
  imageData,
  imageMimeType,
}) {
  return runWorkersAiVisionText({
    workersAi,
    model,
    imageData,
    imageMimeType,
    system:
      "Jestes OCR-em do polskich paragonow. Przepisujesz widoczny tekst, nie robisz JSON.",
    prompt: [
      "Przepisz dokladnie tekst z paragonu widocznego na zdjeciu.",
      "Zachowaj osobne linie. Nie tlumacz, nie streszczaj, nie zgaduj produktow.",
      "Szczegolnie wazne sa: sklep, nazwy produktow, ilosci, ceny i suma.",
      text ? `Tekst OCR z telefonu jako pomoc, moze byc bledny:\n${text}` : "",
    ]
      .filter(Boolean)
      .join("\n"),
  });
}

function isReceiptScanUseful(value) {
  return value.items.length > 0 && value.total > 0;
}

function addReceiptCandidate(candidates, value, source) {
  if (!value || (value.items.length === 0 && value.total <= 0)) {
    return;
  }
  if (source.includes("image") && value.items.length === 0) {
    return;
  }
  candidates.push({ value, source, score: receiptScanScore(value, source) });
}

function bestReceiptCandidate(candidates) {
  if (candidates.length === 0) {
    return null;
  }
  const sorted = [...candidates].sort((a, b) => b.score - a.score);
  const best = sorted[0].value;
  if (isReceiptScanCoherent(best)) {
    return best;
  }

  const coherent = sorted.find((candidate) =>
    isReceiptScanCoherent(candidate.value),
  );
  if (coherent) {
    return coherent.value;
  }
  return { ...best, items: [] };
}

function receiptScanScore(value, source = "") {
  const sum = value.items.reduce((total, item) => total + item.price, 0);
  const hasNamedStore = cleanText(value.storeName) && value.storeName !== "Sklep";
  const hasRealTotal = value.total > 0;
  const coherent = isReceiptScanCoherent(value);
  const sourceBonus =
    source === "image-ocr-ai"
      ? 12
    : source === "image-ai"
      ? -6
    : source === "image-ocr-fallback"
      ? 6
    : source === "text-ai"
      ? 5
      : 0;

  return (
    value.items.length * 25 +
    value.items.filter((item) => item.price > 0).length * 4 +
    (hasRealTotal ? 18 : 0) +
    (hasNamedStore ? 6 : 0) +
    (coherent ? 12 : -25) +
    (sum > 0 ? 4 : 0) +
    sourceBonus
  );
}

function isReceiptScanCoherent(value) {
  if (value.items.length === 0 || value.total <= 0) {
    return true;
  }
  const sum = value.items.reduce((total, item) => total + item.price, 0);
  return sum <= value.total * 1.15;
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

function normalizeReceiptScanDraft(value, hints = []) {
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
  const result = {
    storeName: cleanText(value.storeName) || "Sklep",
    total: Math.max(0, Number(value.total || 0)) || sum,
    items,
  };
  return applyHintsToReceiptScan(result, hints);
}

async function scanRecipeFromRequest({
  env,
  body,
  apiKey,
  model,
  workersAi,
  workersAiModel,
}) {
  const text = cleanText(body?.text);
  const imageData = cleanText(body?.imageData);
  const imageMimeType = cleanText(body?.imageMimeType) || "image/jpeg";
  const hints = await buildRecipeScanHints(env, body);

  if (!text && !imageData) {
    throw new ApiError("Dodaj zdjęcie albo tekst przepisu.", 400);
  }

  const recipeCandidates = [];

  if (apiKey) {
    try {
      const openAiResult = normalizeRecipeScanDraft(
        await scanRecipeWithOpenAi({
          apiKey,
          model,
          text,
          imageData,
          imageMimeType,
          hints,
        }),
        hints,
      );
      addRecipeCandidate(
        recipeCandidates,
        openAiResult,
        imageData ? "openai-image" : "openai",
      );
    } catch (error) {
      if (!text && !workersAi) {
        throw error;
      }
      console.warn("AI recipe scan failed, using text fallback:", error.message);
    }
  }

  const textFallback = text ? tryParseRecipeTextFallback(text, hints) : null;
  addRecipeCandidate(recipeCandidates, textFallback, "fallback");

  if (text && workersAi) {
    try {
      const aiTextResult = normalizeRecipeScanDraft(
        await scanRecipeTextWithWorkersAi({
          workersAi,
          text,
          hints,
        }),
        hints,
      );
      addRecipeCandidate(recipeCandidates, aiTextResult, "text-ai");
    } catch (error) {
      console.warn(
        "Workers AI recipe text scan failed, using image fallback:",
        error.message,
      );
    }
  }

  if (imageData && workersAi) {
    try {
      const imageText = await readRecipeImageTextWithWorkersAi({
        workersAi,
        model: workersAiModel,
        text,
        imageData,
        imageMimeType,
      });
      if (imageText) {
        addRecipeCandidate(
          recipeCandidates,
          tryParseRecipeTextFallback(imageText, hints),
          "image-ocr-fallback",
        );
        try {
          const imageTextAiResult = normalizeRecipeScanDraft(
            await scanRecipeTextWithWorkersAi({
              workersAi,
              text: combineScanText(imageText, text),
              hints,
            }),
            hints,
          );
          addRecipeCandidate(recipeCandidates, imageTextAiResult, "image-ocr-ai");
        } catch (error) {
          console.warn("Workers AI recipe OCR text parse failed:", error.message);
        }
      }
    } catch (error) {
      console.warn("Workers AI recipe image OCR failed:", error.message);
    }

    try {
      const imageAiResult = normalizeRecipeScanDraft(
        await scanRecipeWithWorkersAi({
          workersAi,
          model: workersAiModel,
          text,
          imageData,
          imageMimeType,
          hints,
        }),
        hints,
      );
      addRecipeCandidate(recipeCandidates, imageAiResult, "image-ai");
    } catch (error) {
      if (!text) {
        throw new ApiError(
          `Nie udalo sie odczytac zdjecia przepisu: ${error.message}`,
          error.statusCode || 502,
        );
      }
      console.warn(
        "Workers AI recipe scan failed, using text fallback:",
        error.message,
      );
    }
  }

  const bestCandidate = bestRecipeCandidate(recipeCandidates);
  if (bestCandidate) {
    return bestCandidate;
  }

  if (!text) {
    throw new ApiError(
      "Nie udalo sie odczytac zdjecia. Zrob wyrazniejsze zdjecie albo wpisz tekst recznie.",
      503,
    );
  }

  return normalizeRecipeScanDraft(parseRecipeTextFallback(text), hints);
}

async function scanRecipeWithOpenAi({
  apiKey,
  model,
  text,
  imageData,
  imageMimeType,
  hints,
}) {
  const hintsText = scanHintsPrompt(hints, "Znane skladniki i produkty w tej rodzinie");
  const content = [
    {
      type: "input_text",
      text: [
        "Jesli OCR jest podobny do skladnika ze slownika, uzyj nazwy ze slownika. Slownik jest podpowiedzia, nie lista zamknieta.",
        recipeRulesPrompt(),
        recipeExamplesPrompt(),
        hintsText,
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

async function scanRecipeTextWithWorkersAi({ workersAi, text, hints }) {
  const hintsText = scanHintsPrompt(hints, "Znane skladniki i produkty w tej rodzinie");
  const outputText = await runWorkersAiTextJson({
    workersAi,
    model: defaultWorkersAiTextModel,
    schema: recipeScanJsonSchema(),
    system:
      "Jestes dokladnym parserem polskich przepisow kulinarnych. Odpowiadasz tylko poprawnym JSON.",
    prompt: [
      "Z tekstu OCR przepisu wyciagnij nazwe, kategorie, instrukcje, porcje, makro i skladniki.",
      `Kategorie dozwolone: ${allowedRecipeCategories().join(", ")}.`,
      "Jesli kcal, bialka, tluszczu albo weglowodanow nie ma, ustaw 0.",
      "Skladniki zapisz jako nazwa, ilosc i jednostka. Nie dodawaj skladnikow, ktorych nie ma w tekscie.",
      "Jesli nazwa wyglada jak skladnik ze slownika, popraw ja do nazwy ze slownika.",
      recipeRulesPrompt(),
      recipeExamplesPrompt(),
      hintsText,
      'Zwroc tylko JSON w formacie: {"name":"Nazwa","category":"Obiady","instructions":"Opis","baseServings":4,"caloriesPerServing":0,"proteinPerServing":0,"fatPerServing":0,"carbsPerServing":0,"ingredients":[{"name":"Produkt","quantity":1,"unit":"szt."}]}',
      `Tekst OCR:\n${text}`,
    ].filter(Boolean).join("\n"),
  });
  return parseAiJsonObject(outputText);
}

async function scanRecipeWithWorkersAi({
  workersAi,
  model,
  text,
  imageData,
  imageMimeType,
  hints,
}) {
  const hintsText = scanHintsPrompt(hints, "Znane skladniki i produkty w tej rodzinie");
  return runWorkersAiVisionObject({
    workersAi,
    model,
    imageData,
    imageMimeType,
    system:
      "Jestes dokladnym parserem polskich przepisow kulinarnych. Odpowiadasz tylko poprawnym JSON.",
    prompt: [
      "Odczytaj przepis ze zdjecia. Tekst OCR traktuj tylko jako podpowiedz, bo moze byc pusty albo bledny.",
      "Wyciagnij nazwe, kategorie, opis przygotowania, liczbe porcji, makro na porcje oraz skladniki.",
      `Kategorie dozwolone: ${allowedRecipeCategories().join(", ")}.`,
      "Jesli kcal, bialka, tluszczu albo weglowodanow nie ma, ustaw 0.",
      "Skladniki zapisz jako nazwa, ilosc i jednostka. Nie dodawaj skladnikow, ktorych nie widac.",
      "Jesli nazwa wyglada jak skladnik ze slownika, popraw ja do nazwy ze slownika.",
      recipeRulesPrompt(),
      recipeExamplesPrompt(),
      hintsText,
      'Zwroc tylko JSON w formacie: {"name":"Nazwa","category":"Obiady","instructions":"Opis","baseServings":4,"caloriesPerServing":0,"proteinPerServing":0,"fatPerServing":0,"carbsPerServing":0,"ingredients":[{"name":"Produkt","quantity":1,"unit":"szt."}]}',
      text ? `Tekst OCR/uzytkownika:\n${text}` : "",
    ]
      .filter(Boolean)
      .join("\n"),
  });
}

async function readRecipeImageTextWithWorkersAi({
  workersAi,
  model,
  text,
  imageData,
  imageMimeType,
}) {
  return runWorkersAiVisionText({
    workersAi,
    model,
    imageData,
    imageMimeType,
    system:
      "Jestes OCR-em do polskich przepisow kulinarnych. Przepisujesz widoczny tekst, nie robisz JSON.",
    prompt: [
      "Przepisz dokladnie tekst przepisu widoczny na zdjeciu.",
      "Zachowaj osobne linie i nie streszczaj.",
      "Szczegolnie wazne sa: nazwa, skladniki, ilosci, jednostki, porcje, instrukcja i makro.",
      text ? `Tekst OCR z telefonu jako pomoc, moze byc bledny:\n${text}` : "",
    ]
      .filter(Boolean)
      .join("\n"),
  });
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
        enum: allowedRecipeCategories(),
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

async function buildReceiptScanHints(env, body) {
  const familyHints = await loadFamilyScanHints(env, cleanText(body?.familyId), {
    includeRecipes: true,
    includeReceipts: true,
  });
  return normalizeScanHints([
    ...familyHints,
    ...(Array.isArray(body?.hints) ? body.hints : []),
    ...baseProductVocabulary(),
    ...receiptOcrVocabulary(),
  ]);
}

async function buildRecipeScanHints(env, body) {
  const familyHints = await loadFamilyScanHints(env, cleanText(body?.familyId), {
    includeRecipes: true,
    includeReceipts: false,
  });
  return normalizeScanHints([
    ...familyHints,
    ...(Array.isArray(body?.hints) ? body.hints : []),
    ...baseProductVocabulary(),
    ...baseRecipeVocabulary(),
  ]);
}

async function loadFamilyScanHints(env, familyId, options) {
  if (!env?.DB || !familyId) {
    return [];
  }

  const hints = [];
  const nameQueries = [
    "select name from shopping_items where family_id = ? and is_deleted = 0 order by updated_at desc limit 120",
    "select name from favorite_products where family_id = ? and is_deleted = 0 order by updated_at desc limit 120",
  ];
  if (options.includeRecipes) {
    nameQueries.push(
      "select name from recipe_ingredients where family_id = ? and is_deleted = 0 order by updated_at desc limit 180",
    );
  }

  try {
    for (const sql of nameQueries) {
      const { results } = await env.DB.prepare(sql).bind(familyId).all();
      for (const row of results || []) {
        hints.push(row.name);
      }
    }

    if (options.includeReceipts) {
      const { results } = await env.DB.prepare(
        "select items_json from receipts where family_id = ? and is_deleted = 0 order by updated_at desc limit 80",
      )
        .bind(familyId)
        .all();
      for (const row of results || []) {
        hints.push(...receiptItemNamesFromJson(row.items_json));
      }
    }
  } catch (error) {
    console.warn("Family scan hints failed:", error.message);
  }

  return hints;
}

function receiptItemNamesFromJson(value) {
  try {
    const items = typeof value === "string" ? JSON.parse(value) : value;
    if (!Array.isArray(items)) {
      return [];
    }
    return items.map((item) => item?.name).filter(Boolean);
  } catch (_) {
    return [];
  }
}

function normalizeScanHints(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  const seen = new Set();
  const result = [];
  for (const item of value) {
    const cleaned = cleanText(item).replace(/\s+/g, " ").trim();
    if (cleaned.length < 2 || cleaned.length > 48) {
      continue;
    }
    const key = normalizeHintSearch(cleaned);
    if (!key || seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(cleaned);
    if (result.length >= 320) {
      break;
    }
  }
  return result;
}

function scanHintsPrompt(hints, title) {
  if (!Array.isArray(hints) || hints.length === 0) {
    return "";
  }
  return `${title}. Gdy OCR jest podobny do nazwy ze slownika, uzyj dokladnie tej nazwy:\n- ${hints
    .slice(0, 240)
    .join("\n- ")}`;
}

function receiptExamplesPrompt() {
  return [
    "Przyklady paragonu:",
    "OCR: CHLEB PSZENNY 1 szt 4,99 => name=Chleb pszenny, quantity=1, unit=szt., price=4.99",
    "OCR: MASLO EXTRA 200 g 7,99 => name=Maslo, quantity=200, unit=g, price=7.99",
    "OCR: MLEKO 1 l 3,49 => name=Mleko, quantity=1, unit=l, price=3.49",
    "OCR: SUMA PLN 16,47 => total=16.47, nie produkt",
  ].join("\n");
}

function receiptRulesPrompt() {
  return [
    "Zasady paragonu:",
    "- Cena produktu zwykle stoi na koncu linii; suma/razem/do zaplaty to total, nie produkt.",
    "- Nie zapisuj jako produkty: NIP, numer paragonu, kasa, kasjer, terminal, VAT, rabat, platnosc, reszta, adres.",
    "- Jezeli OCR sklei slowa, rozdziel je wedlug slownika, np. CHLEBPSZENNY -> Chleb pszenny.",
    "- Jezeli linia ma kod lub litere VAT przy produkcie, usun kod i litere, zostaw produkt.",
    "- Jezeli cena nie pasuje do produktu albo wyglada jak numer dokumentu, pomin produkt.",
  ].join("\n");
}

function recipeExamplesPrompt() {
  return [
    "Przyklady przepisu:",
    "OCR: 300 g marchewki => name=Marchew, quantity=300, unit=g",
    "OCR: makaron 200g => name=Makaron, quantity=200, unit=g",
    "OCR: 2 lyzki jogurtu => name=Jogurt, quantity=2, unit=lyzka",
  ].join("\n");
}

function recipeRulesPrompt() {
  return [
    "Zasady przepisu:",
    "- Składniki bierz tylko z tekstu/zdjecia, ale poprawiaj ich nazwy wedlug slownika.",
    "- Instrukcja przygotowania ma trafic do instructions, nie do skladnikow.",
    "- Porcje wykryj z tekstu; gdy ich nie ma, ustaw 4.",
    "- Makro ustaw tylko gdy jest podane w tekscie; gdy go nie ma, wpisz 0.",
    "- Jednostki normalizuj: lyzki/łyżki -> łyżka, lyzeczki -> łyżeczka, zabki -> ząbek, garsc -> garść.",
  ].join("\n");
}

function baseProductVocabulary() {
  return [
    "Chleb",
    "Chleb pszenny",
    "Chleb żytni",
    "Bułki",
    "Bagietka",
    "Tortilla",
    "Mleko",
    "Masło",
    "Margaryna",
    "Śmietana",
    "Śmietanka 30%",
    "Jogurt naturalny",
    "Jogurt owocowy",
    "Kefir",
    "Maślanka",
    "Twaróg",
    "Serek wiejski",
    "Ser żółty",
    "Mozzarella",
    "Feta",
    "Jajka",
    "Szynka",
    "Kiełbasa",
    "Parówki",
    "Boczek",
    "Kurczak",
    "Pierś z kurczaka",
    "Udka z kurczaka",
    "Indyk",
    "Wołowina",
    "Wieprzowina",
    "Schab",
    "Karkówka",
    "Mięso mielone",
    "Łosoś",
    "Dorsz",
    "Tuńczyk",
    "Ziemniaki",
    "Marchew",
    "Pietruszka",
    "Seler",
    "Por",
    "Cebula",
    "Czosnek",
    "Pomidory",
    "Ogórek",
    "Ogórki kiszone",
    "Papryka",
    "Sałata",
    "Rukola",
    "Szpinak",
    "Kapusta",
    "Brokuł",
    "Kalafior",
    "Cukinia",
    "Pieczarki",
    "Groszek",
    "Kukurydza",
    "Fasola",
    "Ciecierzyca",
    "Soczewica",
    "Buraki",
    "Koperek",
    "Natka pietruszki",
    "Jabłka",
    "Banany",
    "Pomarańcze",
    "Cytryny",
    "Truskawki",
    "Borówki",
    "Ryż",
    "Makaron",
    "Kasza gryczana",
    "Kasza jęczmienna",
    "Kasza jaglana",
    "Kuskus",
    "Płatki owsiane",
    "Mąka pszenna",
    "Mąka ziemniaczana",
    "Cukier",
    "Sól",
    "Proszek do pieczenia",
    "Drożdże",
    "Bułka tarta",
    "Olej",
    "Oliwa",
    "Ocet",
    "Majonez",
    "Ketchup",
    "Musztarda",
    "Sos sojowy",
    "Passata",
    "Koncentrat pomidorowy",
    "Pesto",
    "Dżem",
    "Miód",
    "Kakao",
    "Czekolada",
    "Kawa",
    "Herbata",
    "Woda",
    "Sok",
    "Mrożona pizza",
    "Frytki",
    "Pierogi",
    "Warzywa mrożone",
    "Lody",
    "Papryka słodka",
    "Papryka ostra",
    "Pieprz",
    "Curry",
    "Kurkuma",
    "Oregano",
    "Bazylia",
    "Tymianek",
    "Rozmaryn",
    "Cynamon",
    "Imbir",
    "Rosół kostki",
    "Bulion",
    "Tofu",
    "Hummus",
    "Papier toaletowy",
    "Ręcznik papierowy",
    "Mydło",
    "Szampon",
    "Płyn do naczyń",
    "Proszek do prania",
  ];
}

function baseRecipeVocabulary() {
  return [
    "bazylia",
    "bulion",
    "cebula",
    "czosnek",
    "jogurt",
    "makaron",
    "marchew",
    "mąka",
    "mleko",
    "olej",
    "oliwa",
    "papryka",
    "pieprz",
    "pomidory",
    "ryż",
    "ser",
    "sól",
    "śmietana",
    "ziemniaki",
  ];
}

function receiptOcrVocabulary() {
  return [
    "Biedronka",
    "Lidl",
    "Dino",
    "Kaufland",
    "Auchan",
    "Carrefour",
    "Aldi",
    "Żabka",
    "Netto",
    "Stokrotka",
    "Rossmann",
    "Hebe",
  ];
}

function applyHintsToReceiptScan(value, hints) {
  if (!Array.isArray(hints) || hints.length === 0) {
    return value;
  }
  return {
    ...value,
    items: value.items.map((item) => ({
      ...item,
      name: bestHintName(item.name, hints),
    })),
  };
}

function mergeScanIngredients(items) {
  const byKey = new Map();
  for (const item of items) {
    const key = `${normalizeHintSearch(item.name)}|${normalizeUnit(item.unit)}`;
    const existing = byKey.get(key);
    if (existing) {
      existing.quantity += item.quantity;
    } else {
      byKey.set(key, { ...item });
    }
  }
  return [...byKey.values()];
}

function bestHintName(value, hints) {
  const original = cleanText(value);
  if (!original || !Array.isArray(hints) || hints.length === 0) {
    return original;
  }

  const normalized = normalizeHintSearch(normalizeReceiptCandidateName(original));
  if (!normalized) {
    return original;
  }

  const compact = normalized.replace(/\s+/g, "");
  let bestName = "";
  let bestScore = 0;

  for (const hint of hints) {
    const hintName = cleanText(hint);
    const hintKey = normalizeHintSearch(hintName);
    if (!hintName || !hintKey) {
      continue;
    }
    const hintCompact = hintKey.replace(/\s+/g, "");
    let score = 0;

    if (normalized === hintKey) {
      score = 10000 + hintKey.length;
    } else if (containsHintTerm(normalized, hintKey)) {
      score = 9000 + hintKey.length;
    } else if (hintKey.includes(normalized) && normalized.length >= 4) {
      score = 7000 + normalized.length;
    } else if (hintCompact.length >= 4 && compact.includes(hintCompact)) {
      score = 6000 + hintCompact.length;
    } else if (compact.length >= 4 && hintCompact.includes(compact)) {
      score = 5000 + compact.length;
    }

    if (score > bestScore) {
      bestScore = score;
      bestName = hintName;
    }
  }

  return bestName || titleCaseProduct(original);
}

function containsHintTerm(text, term) {
  return ` ${text} `.includes(` ${term} `);
}

function normalizeReceiptCandidateName(value) {
  return cleanText(value)
    .replace(receiptUnitPricePattern, " ")
    .replace(receiptPricePattern, " ")
    .replace(receiptQuantityPattern, " ")
    .replace(/\b\d+(?:[,.]\d+)?\s*x\b/gi, " ")
    .replace(/\bx\b/gi, " ")
    .replace(/\b(pln|zl|zloty|kcal)\b/gi, " ")
    .replace(/\b\d{5,}\b/g, " ")
    .replace(/[*#:;]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeHintSearch(value) {
  return cleanText(value)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replaceAll("ł", "l")
    .replace(/[^a-z0-9 ]/g, " ")
    .replace(/\b\d+(?:[,.]\d+)?\s*(kg|g|l|ml|szt|sztuka|sztuki|op|opak)\b/g, " ")
    .replace(/\b\d{5,}\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function runWorkersAiTextJson({
  workersAi,
  model,
  schema,
  system,
  prompt,
}) {
  if (!workersAi) {
    throw new ApiError("Cloudflare AI nie jest podlaczone do Workera.", 503);
  }
  const response = await workersAi.run(model || defaultWorkersAiTextModel, {
    messages: [
      { role: "system", content: system },
      { role: "user", content: prompt },
    ],
    guided_json: schema,
    max_tokens: 1800,
    temperature: 0.1,
  });
  const outputText = extractWorkersAiOutputText(response);
  if (!outputText) {
    throw new ApiError("AI nie zwrocilo tekstu z danymi.", 502);
  }
  return outputText;
}

async function runWorkersAiVisionObject(options) {
  let lastError = null;
  for (const model of workersAiModelCandidates(options.model)) {
    try {
      const outputText = await runWorkersAiVisionJson({
        ...options,
        model,
      });
      return parseAiJsonObject(outputText);
    } catch (error) {
      lastError = error;
      console.warn(`Workers AI model ${model} failed:`, error.message);
    }
  }

  if (lastError instanceof ApiError) {
    throw lastError;
  }
  throw new ApiError(
    lastError?.message || "Cloudflare AI nie odczytalo obrazu.",
    lastError?.statusCode || 502,
  );
}

function workersAiModelCandidates(model) {
  const values = cleanText(model)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  return [...values, defaultWorkersAiVisionModel, fallbackWorkersAiVisionModel]
    .filter(Boolean)
    .filter((item, index, array) => array.indexOf(item) === index);
}

async function runWorkersAiVisionText(options) {
  const outputs = [];
  let lastError = null;
  for (const model of workersAiModelCandidates(options.model)) {
    try {
      const text = await runWorkersAiVisionRaw({ ...options, model });
      const cleaned = cleanVisionOcrText(text);
      if (cleaned) {
        outputs.push({ text: cleaned, score: visionOcrTextScore(cleaned) });
      }
    } catch (error) {
      lastError = error;
      console.warn(`Workers AI OCR model ${model} failed:`, error.message);
    }
  }

  if (outputs.length > 0) {
    return outputs.sort((a, b) => b.score - a.score)[0].text;
  }
  if (lastError instanceof ApiError) {
    throw lastError;
  }
  throw new ApiError(
    lastError?.message || "Cloudflare AI nie przepisalo tekstu ze zdjecia.",
    lastError?.statusCode || 502,
  );
}

async function runWorkersAiVisionJson({
  workersAi,
  model,
  imageData,
  imageMimeType,
  system,
  prompt,
}) {
  const outputText = await runWorkersAiVisionRaw({
    workersAi,
    model,
    imageData,
    imageMimeType,
    system,
    prompt,
  });
  if (!outputText) {
    throw new ApiError("AI nie zwrocilo tekstu z odczytem obrazu.", 502);
  }
  return outputText;
}

async function runWorkersAiVisionRaw({
  workersAi,
  model,
  imageData,
  imageMimeType,
  system,
  prompt,
}) {
  if (!workersAi) {
    throw new ApiError("Cloudflare AI nie jest podlaczone do Workera.", 503);
  }

  const modelName = model || defaultWorkersAiVisionModel;
  const response = await workersAi.run(modelName, {
    image: base64ToByteArray(imageData),
    prompt: `${system}\n\n${prompt}`,
    max_tokens: 1800,
    temperature: 0.1,
  });

  return extractWorkersAiOutputText(response);
}

function extractWorkersAiOutputText(payload) {
  if (!payload) {
    return "";
  }
  if (typeof payload === "string") {
    return payload;
  }
  if (typeof payload.response === "string") {
    return payload.response;
  }
  if (typeof payload.text === "string") {
    return payload.text;
  }
  if (typeof payload.output_text === "string") {
    return payload.output_text;
  }
  if (typeof payload.description === "string") {
    return payload.description;
  }
  if (typeof payload.result === "string") {
    return payload.result;
  }
  if (payload.result && typeof payload.result === "object") {
    return extractWorkersAiOutputText(payload.result);
  }
  if (Array.isArray(payload.output)) {
    return payload.output.map(extractWorkersAiOutputText).filter(Boolean).join("\n");
  }
  return "";
}

function base64ToByteArray(value) {
  const binary = atob(value.replace(/^data:[^,]+,/, ""));
  const bytes = new Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function cleanVisionOcrText(value) {
  return cleanText(value)
    .replace(/^```(?:text)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .replace(/^(oto|ponizej|poniżej).{0,80}:\s*/i, "")
    .split(/\r?\n/)
    .map((line) =>
      line
        .replace(/^[\s>*-]+/, "")
        .replace(/\s+/g, " ")
        .trim(),
    )
    .filter(Boolean)
    .join("\n")
    .trim();
}

function visionOcrTextScore(value) {
  const text = cleanText(value);
  const lines = text.split(/\r?\n/).filter((line) => line.trim().length >= 2);
  const priceLike = (text.match(/\d+[,.]\d{2}/g) || []).length;
  const unitLike = (text.match(/\b(kg|g|l|ml|szt|porcj|lyzk|łyżk)\b/gi) || [])
    .length;
  return text.length + lines.length * 12 + priceLike * 20 + unitLike * 8;
}

function combineScanText(primary, secondary) {
  const first = cleanText(primary);
  const second = cleanText(secondary);
  if (!first) {
    return second;
  }
  if (!second || normalizeHintSearch(first) === normalizeHintSearch(second)) {
    return first;
  }
  return `${first}\n\nOCR telefonu:\n${second}`;
}

function parseAiJsonObject(text) {
  const trimmed = cleanText(text)
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  try {
    return JSON.parse(trimmed);
  } catch (_) {
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(trimmed.slice(start, end + 1));
      } catch (_) {
        throw new ApiError("AI nie zwrocilo poprawnego JSON.", 502);
      }
    }
    throw new ApiError("AI nie zwrocilo poprawnego JSON.", 502);
  }
}

function tryParseRecipeTextFallback(text, hints = []) {
  try {
    return normalizeRecipeScanDraft(parseRecipeTextFallback(text), hints);
  } catch (_) {
    return null;
  }
}

function addRecipeCandidate(candidates, value, source) {
  if (!value || value.ingredients.length === 0) {
    return;
  }
  candidates.push({ value, source, score: recipeScanScore(value, source) });
}

function bestRecipeCandidate(candidates) {
  if (candidates.length === 0) {
    return null;
  }
  return [...candidates].sort((a, b) => b.score - a.score)[0].value;
}

function recipeScanScore(value, source = "") {
  const hasRealName = cleanText(value.name) && value.name !== "Nowy przepis";
  const hasInstructions = cleanText(value.instructions).length >= 12;
  const hasMacro =
    value.caloriesPerServing > 0 ||
    value.proteinPerServing > 0 ||
    value.fatPerServing > 0 ||
    value.carbsPerServing > 0;
  const sourceBonus =
    source === "image-ocr-ai"
      ? 16
    : source === "image-ai"
      ? -4
    : source === "image-ocr-fallback"
      ? 8
    : source === "text-ai"
      ? 7
      : 0;

  return (
    value.ingredients.length * 18 +
    (hasRealName ? 8 : 0) +
    (hasInstructions ? 12 : 0) +
    (value.baseServings > 1 ? 4 : 0) +
    (hasMacro ? 3 : 0) +
    sourceBonus
  );
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
    /^(.+?)\s+(\d+(?:[,.]\d+)?|\d+\/\d+)\s*(g|kg|ml|l|szt\.?|lyzka|lyzki|lyzeczka|lyzeczki|szklanka|szklanki|opak\.?|op|puszka|puszki|zabek|zabki|garsc|łyżka|łyżki|łyżeczka|łyżeczki|ząbek|garść)?$/i,
  );
  const reverseMatch = cleaned.match(
    /^(\d+(?:[,.]\d+)?|\d+\/\d+)\s*(g|kg|ml|l|szt\.?|lyzka|lyzki|lyzeczka|lyzeczki|szklanka|szklanki|opak\.?|op|puszka|puszki|zabek|zabki|garsc|łyżka|łyżki|łyżeczka|łyżeczki|ząbek|garść)?\s+(.+)$/i,
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

function normalizeRecipeScanDraft(value, hints = []) {
  const ingredients = mergeScanIngredients(Array.isArray(value.ingredients)
    ? value.ingredients
        .map((item) => ({
          name: bestHintName(cleanText(item?.name), hints),
          quantity: Number(item?.quantity || 0),
          unit: normalizeUnit(cleanText(item?.unit) || "szt."),
        }))
        .filter((item) => item.name && item.quantity > 0)
    : []);

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

function productCategoryNames() {
  return [
    "Pieczywo",
    "Nabiał i jajka",
    "Mięso i wędliny",
    "Ryby",
    "Sypkie i makarony",
    "Warzywa",
    "Owoce",
    "Przyprawy i sosy",
    "Słodycze i przekąski",
    "Napoje",
    "Mrożonki",
    "Chemia i dom",
    "Zwierzęta",
    "Inne",
  ];
}

function productCategoryJsonSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["category"],
    properties: {
      category: { type: "string", enum: productCategoryNames() },
    },
  };
}

function normalizeProductCategoryName(value) {
  const normalized = normalizeHintSearch(cleanText(value));
  return (
    productCategoryNames().find(
      (category) => normalizeHintSearch(category) === normalized,
    ) || ""
  );
}

function localProductCategory(name) {
  const cleanName = normalizeHintSearch(name);
  if (!cleanName) {
    return "Inne";
  }

  let bestCategory = "Inne";
  let bestScore = 0;
  for (const category of productCategoryDefinitions()) {
    for (const keyword of category.keywords) {
      const cleanKeyword = normalizeHintSearch(keyword);
      if (!cleanKeyword || !containsProductKeyword(cleanName, cleanKeyword)) {
        continue;
      }
      const words = cleanKeyword.split(" ").filter(Boolean).length;
      const score = cleanKeyword.length * 4 + words * 24 + category.priority;
      if (score > bestScore) {
        bestCategory = category.name;
        bestScore = score;
      }
    }
  }
  return bestCategory;
}

function containsProductKeyword(cleanName, cleanKeyword) {
  if (cleanKeyword.includes(" ")) {
    return ` ${cleanName} `.includes(` ${cleanKeyword} `);
  }
  const tokens = cleanName.split(" ");
  if (cleanKeyword.length <= 3) {
    return tokens.includes(cleanKeyword);
  }
  return tokens.some(
    (token) => token === cleanKeyword || token.startsWith(cleanKeyword),
  );
}

function productCategoryDefinitions() {
  return [
    {
      name: "Pieczywo",
      priority: 8,
      keywords: [
        "chleb",
        "chleb kukurydziany",
        "bułka",
        "kajzerka",
        "bagietka",
        "rogale",
        "tortilla",
        "pita",
        "ciabatta",
      ],
    },
    {
      name: "Nabiał i jajka",
      priority: 8,
      keywords: [
        "mleko",
        "masło",
        "śmietana",
        "jogurt",
        "kefir",
        "twaróg",
        "serek",
        "ser",
        "mozzarella",
        "feta",
        "jajka",
      ],
    },
    {
      name: "Mięso i wędliny",
      priority: 8,
      keywords: [
        "kurczak",
        "indyk",
        "wołowina",
        "wieprzowina",
        "schab",
        "karkówka",
        "mięso",
        "mielone",
        "szynka",
        "kiełbasa",
        "parówki",
        "boczek",
        "salami",
      ],
    },
    {
      name: "Ryby",
      priority: 8,
      keywords: ["ryba", "łosoś", "dorsz", "tuńczyk", "makrela", "śledzie", "krewetki"],
    },
    {
      name: "Sypkie i makarony",
      priority: 14,
      keywords: [
        "płatki kukurydziane",
        "płatki śniadaniowe",
        "płatki owsiane",
        "corn flakes",
        "owsianka",
        "musli",
        "granola",
        "ryż",
        "makaron",
        "kasza",
        "kasza kukurydziana",
        "kuskus",
        "mąka",
        "mąka kukurydziana",
        "cukier",
        "sól",
        "bułka tarta",
        "drożdże",
      ],
    },
    {
      name: "Warzywa",
      priority: 6,
      keywords: [
        "ziemniak",
        "marchew",
        "pietruszka",
        "seler",
        "por",
        "cebula",
        "czosnek",
        "pomidor",
        "ogórek",
        "papryka świeża",
        "sałata",
        "szpinak",
        "kapusta",
        "brokuł",
        "kalafior",
        "cukinia",
        "pieczarki",
        "fasolka",
        "groszek",
        "kukurydza",
        "kukurydza w puszce",
        "fasola",
        "ciecierzyca",
        "soczewica",
        "burak",
      ],
    },
    {
      name: "Owoce",
      priority: 6,
      keywords: ["jabłko", "banan", "pomarańcza", "cytryna", "gruszka", "winogrona", "truskawki", "maliny", "kiwi", "mango"],
    },
    {
      name: "Przyprawy i sosy",
      priority: 10,
      keywords: ["olej", "olej kukurydziany", "oliwa", "ocet", "majonez", "ketchup", "musztarda", "sos", "passata", "koncentrat", "pesto", "przyprawa", "pieprz", "curry", "bulion"],
    },
    {
      name: "Słodycze i przekąski",
      priority: 12,
      keywords: ["chrupki kukurydziane", "paluszki kukurydziane", "nachosy", "popcorn", "czekolada", "baton", "ciastka", "chipsy", "paluszki", "krakersy", "orzechy", "lody", "budyń", "kisiel", "galaretka"],
    },
    {
      name: "Napoje",
      priority: 8,
      keywords: ["woda", "sok", "napój", "cola", "pepsi", "lemoniada", "syrop", "kawa", "herbata", "energetyk"],
    },
    {
      name: "Mrożonki",
      priority: 9,
      keywords: ["mrożone", "mrożonka", "frytki", "pizza mrożona", "pierogi", "kopytka", "warzywa mrożone"],
    },
    {
      name: "Chemia i dom",
      priority: 8,
      keywords: ["papier toaletowy", "ręcznik papierowy", "chusteczki", "mydło", "szampon", "pasta do zębów", "płyn do naczyń", "tabletki do zmywarki", "proszek do prania", "worki na śmieci", "folia aluminiowa"],
    },
    {
      name: "Zwierzęta",
      priority: 8,
      keywords: ["karma dla psa", "karma dla kota", "karma", "żwirek"],
    },
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
    szklanki: "szklanka",
    opak: "opak.",
    op: "opak.",
    puszki: "puszka",
    zabek: "ząbek",
    zabki: "ząbek",
    garsc: "garść",
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
