export type AdminProfileRow = {
  id: string;
  display_name?: string | null;
  email?: string | null;
  role?: string | null;
  whatsapp_number?: string | null;
};

type SupabaseClient = any;

const PROFILE_TABLES = ["dinein_profiles", "profiles"] as const;
const ADMIN_PROFILE_SELECTS = [
  "id, display_name, email, role, whatsapp_number",
  "id, display_name, role, whatsapp_number",
  "id, display_name, email, role",
  "id, display_name, role",
] as const;

function errorString(value: unknown): string {
  if (!value || typeof value !== "object") return "";
  const record = value as Record<string, unknown>;
  return [
    record.code,
    record.message,
    record.details,
    record.hint,
  ].filter((part) => typeof part === "string" && part.length > 0).join(" ")
    .toLowerCase();
}

function isCompatibleSchemaError(error: unknown): boolean {
  const message = errorString(error);
  return message.includes("does not exist") ||
    message.includes("could not find the table") ||
    message.includes("could not find the column") ||
    message.includes("schema cache");
}

export async function listAdminProfilesWithFallback(
  supabase: SupabaseClient,
): Promise<AdminProfileRow[]> {
  let lastSchemaError: unknown = null;

  for (const table of PROFILE_TABLES) {
    for (const select of ADMIN_PROFILE_SELECTS) {
      const { data, error } = await supabase
        .from(table)
        .select(select)
        .eq("role", "admin");

      if (!error) {
        return (data ?? []) as AdminProfileRow[];
      }

      if (!isCompatibleSchemaError(error)) {
        throw error;
      }

      lastSchemaError = error;
    }
  }

  throw lastSchemaError ??
    new Error("No compatible admin profile table found.");
}

export async function isAdminUserWithFallback(
  supabase: SupabaseClient,
  userId: string,
): Promise<boolean> {
  let lastSchemaError: unknown = null;

  for (const table of PROFILE_TABLES) {
    const { data, error } = await supabase
      .from(table)
      .select("role")
      .eq("id", userId)
      .maybeSingle();

    if (!error) {
      return data?.role == "admin";
    }

    if (!isCompatibleSchemaError(error)) {
      throw error;
    }

    lastSchemaError = error;
  }

  throw lastSchemaError ?? new Error("No compatible profile table found.");
}

export async function persistAdminWhatsAppNumberWithFallback(
  supabase: SupabaseClient,
  profileId: string,
  normalizedPhone: string,
): Promise<void> {
  let lastSchemaError: unknown = null;

  for (const table of PROFILE_TABLES) {
    const { error } = await supabase
      .from(table)
      .update({ whatsapp_number: normalizedPhone })
      .eq("id", profileId);

    if (!error) {
      return;
    }

    if (!isCompatibleSchemaError(error)) {
      throw error;
    }

    lastSchemaError = error;
  }

  throw lastSchemaError ??
    new Error("No compatible profile table available for WhatsApp sync.");
}
