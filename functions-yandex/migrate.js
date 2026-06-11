#!/usr/bin/env node

const {execSync} = require("child_process");
const fs = require("fs");
const path = require("path");

const OUTPUT_DIR = path.join(__dirname, "exports");

if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, {recursive: true});

const COLLECTIONS = [
  "owners", "drivers", "vehicles", "trips",
  "expenses", "salaryRules", "salaryPayments", "tickets",
];

console.log("=== Numino Firestore → YDB Migration ===\n");

// Этап 1: экспорт из Firestore через gcloud
console.log("Этап 1: Экспорт из Firestore через gcloud...");
COLLECTIONS.forEach((col) => {
  const outFile = path.join(OUTPUT_DIR, `${col}.json`);
  try {
    execSync(
      `gcloud firestore export gs://YOUR_BUCKET/backups/${col} --collection-ids=${col}`,
      {stdio: "inherit"}
    );
    console.log(`  [OK] ${col}`);
  } catch (e) {
    console.log(`  [SKIP] ${col} — нужен доступ к gcloud`);
  }
});

// Этап 2: конвертация JSON → YQL INSERT
console.log("\nЭтап 2: Конвертация JSON → YQL...");
const yqlFile = path.join(OUTPUT_DIR, "import.yql");
const yqlLines: string[] = ["-- Auto-generated YQL import script", ""];

COLLECTIONS.forEach((col) => {
  const jsonFile = path.join(OUTPUT_DIR, `${col}.json`);
  if (!fs.existsSync(jsonFile)) return;

  const raw = fs.readFileSync(jsonFile, "utf8");
  const lines = raw.trim().split("\n");

  const tableName = col.replace(/([A-Z])/g, "_$1").toLowerCase();
  const columns = COLUMN_MAP[col] || [];

  lines.forEach((line) => {
    try {
      const doc = JSON.parse(line);
      const values = columns.map((c) => escapeYqlValue(doc[c.firestore] ?? null));
      yqlLines.push(
        `INSERT INTO ${tableName} (${columns.map((c) => c.ydb).join(", ")})`,
        `VALUES (${values.join(", ")});`
      );
    } catch (e) {
      // skip malformed lines
    }
  });

  console.log(`  [OK] ${col} → ${tableName}`);
});

yqlLines.push("");
fs.writeFileSync(yqlFile, yqlLines.join("\n"));
console.log(`\nYQL сгенерирован: ${yqlFile}`);

// Этап 3: загрузка в YDB
console.log("\nЭтап 3: Загрузка в YDB...");
console.log("  Выполните вручную:");
console.log(`    ydb -e grpc://YOUR_YDB_ENDPOINT -d /ru-central1/YOUR_DB scripting yql -f ${yqlFile}`);
console.log("\nИли через консоль Яндекс.Облака:");
console.log("  https://console.yandex.cloud → YDB → SQL");

function escapeYqlValue(val: any): string {
  if (val === null || val === undefined) return "NULL";
  if (typeof val === "boolean") return val ? "TRUE" : "FALSE";
  if (typeof val === "number") return String(val);
  if (val instanceof Object && val._seconds) return `DateTime::FromSeconds(${val._seconds})`;
  const escaped = String(val).replace(/'/g, "''").replace(/\\/g, "\\\\");
  return `'${escaped}'`;
}

const COLUMN_MAP: Record<string, Array<{firestore: string; ydb: string}>> = {
  owners: [
    {firestore: "uid", ydb: "uid"},
    {firestore: "email", ydb: "email"},
    {firestore: "displayName", ydb: "display_name"},
    {firestore: "role", ydb: "role"},
    {firestore: "phone", ydb: "phone"},
    {firestore: "companyName", ydb: "company_name"},
    {firestore: "driverIds", ydb: "driver_ids"},
    {firestore: "active", ydb: "active"},
    {firestore: "createdAt", ydb: "created_at"},
  ],
  drivers: [
    {firestore: "uid", ydb: "uid"},
    {firestore: "ownerId", ydb: "owner_id"},
    {firestore: "email", ydb: "email"},
    {firestore: "displayName", ydb: "display_name"},
    {firestore: "role", ydb: "role"},
    {firestore: "licenseNumber", ydb: "license_number"},
    {firestore: "medExamNumber", ydb: "med_exam_number"},
    {firestore: "medExamDate", ydb: "med_exam_date"},
    {firestore: "createdAt", ydb: "created_at"},
  ],
  vehicles: [
    {firestore: "id", ydb: "id"},
    {firestore: "ownerId", ydb: "owner_id"},
    {firestore: "plateNumber", ydb: "plate_number"},
    {firestore: "brand", ydb: "brand"},
    {firestore: "model", ydb: "model"},
    {firestore: "vin", ydb: "vin"},
    {firestore: "fuelType", ydb: "fuel_type"},
    {firestore: "isActive", ydb: "is_active"},
    {firestore: "techExamNumber", ydb: "tech_exam_number"},
    {firestore: "createdAt", ydb: "created_at"},
  ],
  trips: [
    {firestore: "id", ydb: "id"},
    {firestore: "driverId", ydb: "driver_id"},
    {firestore: "vehicleId", ydb: "vehicle_id"},
    {firestore: "status", ydb: "status"},
    {firestore: "startTime", ydb: "start_time"},
    {firestore: "startLatitude", ydb: "start_latitude"},
    {firestore: "startLongitude", ydb: "start_longitude"},
    {firestore: "endTime", ydb: "end_time"},
    {firestore: "mileage", ydb: "mileage"},
    {firestore: "mileageSource", ydb: "mileage_source"},
    {firestore: "cargoDescription", ydb: "cargo_description"},
    {firestore: "routeDescription", ydb: "route_description"},
    {firestore: "income", ydb: "income"},
    {firestore: "waybillUrl", ydb: "waybill_url"},
    {firestore: "waybillUuid", ydb: "waybill_uuid"},
    {firestore: "createdAt", ydb: "created_at"},
  ],
  expenses: [
    {firestore: "id", ydb: "id"},
    {firestore: "tripId", ydb: "trip_id"},
    {firestore: "driverId", ydb: "driver_id"},
    {firestore: "amount", ydb: "amount"},
    {firestore: "category", ydb: "category"},
    {firestore: "description", ydb: "description"},
    {firestore: "receiptUrl", ydb: "receipt_url"},
    {firestore: "latitude", ydb: "latitude"},
    {firestore: "longitude", ydb: "longitude"},
    {firestore: "createdAt", ydb: "created_at"},
  ],
  salaryRules: [
    {firestore: "id", ydb: "id"},
    {firestore: "ownerId", ydb: "owner_id"},
    {firestore: "driverId", ydb: "driver_id"},
    {firestore: "type", ydb: "type"},
    {firestore: "percentValue", ydb: "percent_value"},
    {firestore: "fixedValue", ydb: "fixed_value"},
    {firestore: "isActive", ydb: "is_active"},
    {firestore: "createdAt", ydb: "created_at"},
  ],
  salaryPayments: [
    {firestore: "id", ydb: "id"},
    {firestore: "ownerId", ydb: "owner_id"},
    {firestore: "driverId", ydb: "driver_id"},
    {firestore: "totalIncome", ydb: "total_income"},
    {firestore: "calculatedSalary", ydb: "calculated_salary"},
    {firestore: "ruleType", ydb: "rule_type"},
    {firestore: "ruleValue", ydb: "rule_value"},
    {firestore: "status", ydb: "status"},
    {firestore: "createdAt", ydb: "created_at"},
  ],
};
