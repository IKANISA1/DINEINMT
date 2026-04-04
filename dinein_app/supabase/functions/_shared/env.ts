export function getEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export function optionalEnv(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  return value && value.length > 0 ? value : null;
}

export function intEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name)?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function boolEnv(key: string, fallback: boolean): boolean {
  const raw = Deno.env.get(key)?.trim().toLowerCase();
  if (!raw) return fallback;
  return raw === "1" || raw === "true" || raw === "yes" || raw === "on";
}

export function numberValue(value: unknown): number | undefined {
  if (typeof value == "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value == "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

export function stringValue(value: unknown): string | undefined {
  if (typeof value == "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (typeof value == "number" || typeof value == "boolean") {
    return String(value);
  }
  return undefined;
}

export function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value == "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}
