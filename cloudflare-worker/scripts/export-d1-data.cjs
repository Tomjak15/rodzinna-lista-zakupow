const fs = require("node:fs");
const path = require("node:path");

const [dbPathArg, outputPathArg] = process.argv.slice(2);

if (!dbPathArg || !outputPathArg) {
  console.error("Usage: node scripts/export-d1-data.cjs <sqlite-db> <output.sql>");
  process.exit(1);
}

const root = path.resolve(__dirname, "..", "..");
const sqlitePackagePath = path.join(root, "server", "node_modules", "better-sqlite3");
const Database = require(sqlitePackagePath);

const dbPath = path.resolve(dbPathArg);
const outputPath = path.resolve(outputPathArg);

if (!fs.existsSync(dbPath)) {
  console.error(`SQLite database not found: ${dbPath}`);
  process.exit(1);
}

const tables = [
  {
    name: "families",
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
  },
  {
    name: "members",
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
  },
  {
    name: "shopping_items",
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
  },
  {
    name: "meals",
    columns: [
      "id",
      "family_id",
      "name",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
  },
  {
    name: "recipes",
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
    orderBy: "case when parent_recipe_id is null then 0 else 1 end, created_at asc",
  },
  {
    name: "recipe_ingredients",
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
  },
  {
    name: "meal_plans",
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
  },
  {
    name: "calendar_events",
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
  },
  {
    name: "nutrition_goals",
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
  },
  {
    name: "nutrition_entries",
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
      "image_data",
      "image_mime_type",
      "created_at",
      "updated_at",
      "created_by",
      "is_deleted",
    ],
  },
  {
    name: "training_entries",
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
  },
  {
    name: "favorite_products",
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
  },
  {
    name: "receipts",
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
  },
];

const db = new Database(dbPath, { readonly: false });
db.pragma("wal_checkpoint(TRUNCATE)");

const lines = [
  "-- Data export for Cloudflare D1.",
  "-- Generated from local SQLite. Do not commit this file if it contains real family data.",
];

let totalRows = 0;

for (const table of tables) {
  const existingColumns = db
    .prepare(`pragma table_info(${table.name})`)
    .all()
    .map((column) => column.name);
  if (existingColumns.length === 0) {
    continue;
  }

  const columns = table.columns.filter((column) => existingColumns.includes(column));
  const rows = db
    .prepare(
      `select ${columns.join(", ")} from ${table.name} order by ${
        table.orderBy || "created_at asc"
      }`,
    )
    .all();

  for (const row of rows) {
    const values = columns.map((column) => sqlValue(table.name, column, row[column]));
    lines.push(
      `insert or replace into ${table.name} (${columns.join(", ")}) values (${values.join(
        ", ",
      )});`,
    );
    totalRows += 1;
  }
}

lines.push("");

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, lines.join("\n"), "utf8");

console.log(`Exported ${totalRows} rows to ${outputPath}`);

function sqlValue(table, column, value) {
  if (value === null || value === undefined) {
    return "null";
  }
  if (
    table === "receipts" &&
    column === "image_data" &&
    typeof value === "string"
  ) {
    return "null";
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? String(value) : "0";
  }
  return `'${String(value).replace(/'/g, "''")}'`;
}
