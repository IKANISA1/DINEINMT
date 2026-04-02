import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export type JsonRecord = Record<string, unknown>;

function getEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`[whatsapp] Missing environment variable: ${name}`);
  }
  return value;
}

const graphApiVersion = Deno.env.get("WHATSAPP_GRAPH_API_VERSION") ?? "v22.0";

/**
 * Executes a raw message post payload to the Meta Graph API.
 */
export async function postWhatsAppMessage(payload: JsonRecord) {
  const phoneNumberId = getEnv("WHATSAPP_PHONE_NUMBER_ID");
  const accessToken = getEnv("WHATSAPP_ACCESS_TOKEN");
  const endpoint =
    `https://graph.facebook.com/${graphApiVersion}/${phoneNumberId}/messages`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const text = await response.text();
  let data: unknown = text;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }

  return {
    ok: response.ok,
    status: response.status,
    data,
  };
}

/**
 * Helper to build a standard Template message payload.
 */
export function buildWhatsAppTemplatePayload(
  recipientPhone: string,
  templateName: string,
  components: Array<JsonRecord> = [],
  languageCode = "en",
): JsonRecord {
  return {
    messaging_product: "whatsapp",
    to: recipientPhone.replace(/\D/g, ""), // Meta requires raw digits
    type: "template",
    template: {
      name: templateName,
      language: { code: languageCode },
      components,
    },
  };
}

/**
 * Helper to build a standard Text message payload.
 */
export function buildWhatsAppTextPayload(
  recipientPhone: string,
  body: string,
  previewUrl = false,
): JsonRecord {
  return {
    messaging_product: "whatsapp",
    to: recipientPhone.replace(/\D/g, ""),
    type: "text",
    text: {
      preview_url: previewUrl,
      body,
    },
  };
}
