import {
  assert,
  assertAlmostEquals,
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  normalizeBiopayAction,
  normalizeBiopayClientInstallId,
  normalizeBiopayDisplayName,
  normalizeBiopayEmbedding,
  normalizeBiopayId,
  normalizeBiopayManagementCode,
  normalizeBiopayMatchThreshold,
  normalizeBiopayUssd,
  resolveAllowedBiopayOrigin,
  signOwnerToken,
  toVectorLiteral,
  verifyOwnerToken,
  enforceMatchRateLimit,
} from "./index.ts";

Deno.env.set("SUPABASE_URL", "https://mock.supabase.co");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "mock-key");
Deno.env.set("BIOPAY_OWNER_TOKEN_SECRET", "test-owner-secret");
Deno.env.set("BIOPAY_MANAGE_CODE_PEPPER", "test-manage-pepper");

Deno.test("normalizeBiopayAction accepts supported action", () => {
  assertEquals(normalizeBiopayAction("match_face"), "match_face");
});

Deno.test("normalizeBiopayDisplayName collapses whitespace", () => {
  assertEquals(
    normalizeBiopayDisplayName("  Uwimana    Marie  "),
    "Uwimana Marie",
  );
});

Deno.test("normalizeBiopayId rejects invalid values", () => {
  assertThrows(() => normalizeBiopayId("12"));
  assertEquals(normalizeBiopayId("123456"), "123456");
});

Deno.test("normalizeBiopayManagementCode validates digit count", () => {
  assertEquals(normalizeBiopayManagementCode("123456"), "123456");
  assertThrows(() => normalizeBiopayManagementCode("1234"));
});

Deno.test("normalizeBiopayUssd canonicalizes Rwanda MTN receive-money string", () => {
  assertEquals(
    normalizeBiopayUssd("*182*1*1*0788123456#"),
    {
      ussdString: "*182*1*1*0788123456#",
      ussdNormalized: "*182*1*1*0788123456#",
      recipientPhoneE164: "+250788123456",
    },
  );
});

Deno.test("normalizeBiopayUssd also accepts raw Rwanda phone numbers", () => {
  assertEquals(
    normalizeBiopayUssd("+250788123456"),
    {
      ussdString: "*182*1*1*0788123456#",
      ussdNormalized: "*182*1*1*0788123456#",
      recipientPhoneE164: "+250788123456",
    },
  );
});

Deno.test("normalizeBiopayEmbedding returns an L2-normalized vector", () => {
  const embedding = normalizeBiopayEmbedding(
    Array.from({ length: 192 }, () => 1),
  );
  const norm = Math.sqrt(
    embedding.reduce((sum, value) => sum + (value * value), 0),
  );

  assertAlmostEquals(norm, 1, 1e-9);
  assertEquals(embedding.length, 192);
  assert(toVectorLiteral(embedding).startsWith("["));
});

Deno.test("normalizeBiopayEmbedding rejects wrong shape", () => {
  assertThrows(() => normalizeBiopayEmbedding([1, 2, 3]));
});

Deno.test("match threshold cannot be lowered below the server floor", () => {
  Deno.env.set("BIOPAY_DEFAULT_MATCH_THRESHOLD", "0.72");
  Deno.env.set("BIOPAY_MIN_MATCH_THRESHOLD", "0.80");

  assertEquals(normalizeBiopayMatchThreshold(undefined), 0.80);
  assertThrows(() => normalizeBiopayMatchThreshold(0.79));
  assertEquals(normalizeBiopayMatchThreshold(0.80), 0.80);
});

Deno.test("required client install id is enforced for match requests", () => {
  assertThrows(() => normalizeBiopayClientInstallId("", { required: true }));
  assertEquals(
    normalizeBiopayClientInstallId("install-123", { required: true }),
    "install-123",
  );
});

Deno.test("only configured browser origins are allowed for biopay", () => {
  Deno.env.set(
    "BIOPAY_ALLOWED_ORIGINS",
    "https://dineinrw.ikanisa.com, https://biopay.dinein.test",
  );

  assertEquals(
    resolveAllowedBiopayOrigin("https://dineinrw.ikanisa.com"),
    "https://dineinrw.ikanisa.com",
  );
  assertEquals(
    resolveAllowedBiopayOrigin("https://biopay.dinein.test/path"),
    "https://biopay.dinein.test",
  );
  assertEquals(resolveAllowedBiopayOrigin("https://evil.example"), null);
});

Deno.test("owner token roundtrip verifies payload", async () => {
  const token = await signOwnerToken({
    sub: "profile-123",
    biopay_id: "123456",
    owner_token_version: 1,
    exp: Math.floor(Date.now() / 1000) + 60,
  });
  const payload = await verifyOwnerToken(token);

  assertEquals(payload.sub, "profile-123");
  assertEquals(payload.biopay_id, "123456");
});

Deno.test("expired owner token is rejected", async () => {
  const token = await signOwnerToken({
    sub: "profile-123",
    biopay_id: "123456",
    owner_token_version: 1,
    exp: Math.floor(Date.now() / 1000) - 1,
  });

  await assertRejects(() => verifyOwnerToken(token));
});

Deno.test("enforceMatchRateLimit blocks after reaching the threshold", async () => {
  Deno.env.set("BIOPAY_MATCH_RATE_LIMIT_MAX_REQUESTS", "2");

  const mockSupabase = {
    from: (table: string) => {
      if (table === "biopay_match_audit") {
        return {
          select: () => ({
            eq: () => ({
              gte: () => Promise.resolve({ count: 2, error: null }),
            }),
          }),
          insert: () => Promise.resolve({ error: null }),
        };
      }
      return {};
    },
  } as any;

  const req = new Request("https://api.test", {
    headers: { "x-forwarded-for": "1.1.1.1" },
  });

  try {
    await enforceMatchRateLimit(mockSupabase, req, "install-123", "Pixel 7");
    throw new Error("Should have thrown 429");
  } catch (err: any) {
    assertEquals(err.status, 429);
    assertEquals(err.details?.code, "rate_limited");
  }
});
