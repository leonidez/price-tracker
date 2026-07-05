// Thin fetch wrapper: base URL + bearer token from env, JSON in/out, typed errors.
// EXPO_PUBLIC_* vars are inlined at build time (see .env.example).

const BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? "";
const API_TOKEN = process.env.EXPO_PUBLIC_API_TOKEN ?? "";

export const apiBaseUrl = BASE_URL;

export class ApiError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message?: string) {
    super(message ?? code);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  body?: unknown;
}

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const response = await fetch(`${BASE_URL}/api/v1${path}`, {
    method: options.method ?? "GET",
    headers: {
      Authorization: `Bearer ${API_TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  if (response.status === 204) {
    return undefined as T;
  }

  const text = await response.text();
  const data: unknown = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const envelope = (data as { error?: { code?: string; message?: string } } | null)?.error;
    throw new ApiError(response.status, envelope?.code ?? "unknown", envelope?.message);
  }

  return data as T;
}
