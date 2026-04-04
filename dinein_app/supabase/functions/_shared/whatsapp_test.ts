import { assertEquals } from "jsr:@std/assert@1";
import {
  buildWhatsAppTemplatePayload,
  buildWhatsAppTextPayload,
} from "./whatsapp.ts";

Deno.test(
  "buildWhatsAppTemplatePayload strips non-digit chars from phone",
  () => {
    const payload = buildWhatsAppTemplatePayload(
      "+356 7718 6199",
      "dinein_otp",
      [{ type: "body", parameters: [{ type: "text", text: "123456" }] }],
    );

    assertEquals(payload.messaging_product, "whatsapp");
    assertEquals(payload.to, "35677186199");
    assertEquals(payload.type, "template");

    const template = payload.template as Record<string, unknown>;
    assertEquals(template.name, "dinein_otp");

    const language = template.language as Record<string, unknown>;
    assertEquals(language.code, "en");

    const components = template.components as Array<Record<string, unknown>>;
    assertEquals(components.length, 1);
    assertEquals(components[0].type, "body");
  },
);

Deno.test("buildWhatsAppTemplatePayload defaults to en language", () => {
  const payload = buildWhatsAppTemplatePayload("+35699999999", "test_template");
  const template = payload.template as Record<string, unknown>;
  const language = template.language as Record<string, unknown>;

  assertEquals(language.code, "en");
});

Deno.test("buildWhatsAppTemplatePayload respects custom language", () => {
  const payload = buildWhatsAppTemplatePayload(
    "+25078",
    "test_rw",
    [],
    "rw",
  );
  const template = payload.template as Record<string, unknown>;
  const language = template.language as Record<string, unknown>;

  assertEquals(language.code, "rw");
});

Deno.test("buildWhatsAppTemplatePayload normalizes digits-only phone", () => {
  const payload = buildWhatsAppTemplatePayload("35677186199", "test");
  assertEquals(payload.to, "35677186199");
});

Deno.test("buildWhatsAppTextPayload produces correct structure", () => {
  const payload = buildWhatsAppTextPayload(
    "+356 7718 6199",
    "Your OTP is 654321.",
  );

  assertEquals(payload.messaging_product, "whatsapp");
  assertEquals(payload.to, "35677186199");
  assertEquals(payload.type, "text");

  const text = payload.text as Record<string, unknown>;
  assertEquals(text.preview_url, false);
  assertEquals(text.body, "Your OTP is 654321.");
});

Deno.test(
  "buildWhatsAppTextPayload supports preview_url flag",
  () => {
    const payload = buildWhatsAppTextPayload(
      "+35699999999",
      "Check https://dineinmt.ikanisa.com",
      true,
    );

    const text = payload.text as Record<string, unknown>;
    assertEquals(text.preview_url, true);
  },
);

Deno.test("buildWhatsAppTextPayload strips spaces and hyphens from phone", () => {
  const payload = buildWhatsAppTextPayload("+356-77-18-61-99", "test");
  assertEquals(payload.to, "35677186199");
});

Deno.test(
  "buildWhatsAppTemplatePayload handles empty components array",
  () => {
    const payload = buildWhatsAppTemplatePayload("+35699999999", "welcome", []);
    const template = payload.template as Record<string, unknown>;
    const components = template.components as unknown[];

    assertEquals(components.length, 0);
  },
);
