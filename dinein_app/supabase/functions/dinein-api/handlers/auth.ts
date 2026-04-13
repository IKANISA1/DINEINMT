import {
  type JsonRecord,
  adminClient,
  HttpError,
  isAdmin,
  ok,
  requireSelfOrAdmin,
  requireString,
} from "../core.ts";
import { stringValue } from "../../_shared/env.ts";

// Auth handlers — profile and role management
// Actions: create_profile, get_user_role
export async function handleCreateProfile(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const userId = requireString(body, "userId", "user_id");
  const callerId = await requireSelfOrAdmin(supabase, req, userId);
  const callerIsAdmin = await isAdmin(supabase, callerId);

  const { error } = await supabase.from("dinein_profiles").upsert({
    id: userId,
    display_name: stringValue(body.displayName) ??
      stringValue(body.display_name) ?? null,
    email: stringValue(body.email) ?? null,
    role: callerIsAdmin ? (stringValue(body.role) ?? "customer") : "customer",
  });

  if (error) {
    console.error("[dinein-api] create profile failed", error);
    throw new HttpError(500, "Could not create the user profile.");
  }

  return ok(true, 201);
}

export async function handleGetUserRole(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const userId = requireString(body, "userId", "user_id");
  await requireSelfOrAdmin(supabase, req, userId);

  const { data, error } = await supabase
    .from("dinein_profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    console.error("[dinein-api] get user role failed", error);
    throw new HttpError(500, "Could not load the user role.");
  }

  return ok(data?.role ?? null);
}
