import type {HttpRequest, HttpResponse} from "@yandex-cloud/nodejs-sdk";
import {Database, Session} from "@yandex-cloud/nodejs-sdk/dist/generated/yandex/cloud/ydb/v1";

const db = new Database({});

const endpoints: Record<string, (req: HttpRequest) => Promise<HttpResponse>> = {
  startTrip: async (req) => { return {statusCode: 200, body: {tripId: "pending"}}; },
  addTrackPoint: async (req) => { return {statusCode: 200, body: {success: true}}; },
  addTrackPointsBatch: async (req) => { return {statusCode: 200, body: {success: true}}; },
  endTrip: async (req) => { return {statusCode: 200, body: {mileage: 0, mileageSource: "manual"}}; },
  updateTrip: async (req) => { return {statusCode: 200, body: {success: true}}; },
  getMyTrips: async (req) => { return {statusCode: 200, body: {trips: [], count: 0}}; },
  addExpense: async (req) => { return {statusCode: 200, body: {expenseId: "pending"}}; },
  getTripExpenses: async (req) => { return {statusCode: 200, body: {expenses: [], total: 0, count: 0}}; },
  getDriverExpensesReport: async (req) => { return {statusCode: 200, body: {expenses: [], total: 0, byCategory: {}, count: 0}}; },
  generateWaybill: async (req) => { return {statusCode: 200, body: {success: true, waybillUrl: "pending"}}; },
  setSalaryRule: async (req) => { return {statusCode: 200, body: {ruleId: "pending"}}; },
  getSalaryRule: async (req) => { return {statusCode: 200, body: {rule: null}}; },
  calculateSalary: async (req) => { return {statusCode: 200, body: {calculatedSalary: 0}}; },
  getSalaryHistory: async (req) => { return {statusCode: 200, body: {payments: [], count: 0}}; },
  signWaybill: async (req) => { return {statusCode: 200, body: {success: true, signatureUrl: "stub"}}; },
  ping: async (req) => { return {statusCode: 200, body: {status: "ok", timestamp: new Date().toISOString()}}; },
};

export async function handler(req: HttpRequest): Promise<HttpResponse> {
  if (req.method === "OPTIONS") {
    return {
      statusCode: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,Authorization,X-API-Key",
      },
      body: "",
    };
  }

  const path = (req.url || "/").replace(/^\//, "");
  const fn = path.split("/").pop() || "";

  if (!endpoints[fn]) {
    return {statusCode: 404, body: {error: `Unknown function: ${fn}`}};
  }

  try {
    const response = await endpoints[fn](req);
    return {
      ...response,
      headers: {
        ...(response.headers || {}),
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
    };
  } catch (err: any) {
    return {
      statusCode: err.statusCode || 500,
      body: {error: err.message || "Internal error"},
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
    };
  }
}
