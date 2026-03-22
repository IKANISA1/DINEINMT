import {
  assertEquals,
  assertFalse,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  assertValidOrderStatusTransition,
  buildApprovedClaimUpdate,
  buildApprovedVenueLinkage,
  buildClaimAccessAuditUpdate,
  buildVenueAccessAuditUpdate,
  generateOrderNumber,
  handleAppRequest,
  normalizePaymentMethod,
  normalizeVenueSupportedPaymentMethods,
  normalizeWaveTableNumber,
  orderPaymentStatusForMethod,
  resetGoogleMapsSearchRateLimitState,
  resetWaveRateLimitState,
  sanitizeOrderInsert,
  shouldGenerateAiVenueProfileImage,
  venueOrderingReadiness,
} from "./index.ts";

// Set required env vars
Deno.env.set("SUPABASE_URL", "https://mock.supabase.co");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "mock-key");
Deno.env.set("SUPABASE_ANON_KEY", "mock-anon-key");
Deno.env.set("DINEIN_ADMIN_SESSION_SECRET", "mock-secret");
Deno.env.set("DINEIN_VENUE_SESSION_SECRET", "mock-secret");

// A fake JWT that decodes to { "role": "service_role" }
// Header: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 ({"alg":"HS256","typ":"JWT"})
// Payload: eyJyb2xlIjoic2VydmljZV9yb2xlIn0 ({"role":"service_role"})
// Signature: dummy
const serviceRoleJwt =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.dummy";

const originalFetch = globalThis.fetch;

// Helper to mock fetch calls if needed by the handler
function mockFetch(handler: (req: Request) => Promise<Response> | Response) {
  globalThis.fetch = async (
    input: Request | URL | string,
    init?: RequestInit,
  ) => {
    let req: Request;
    if (input instanceof Request) {
      req = input;
    } else {
      req = new Request(input.toString(), init);
    }
    return await handler(req);
  };
}

function restoreFetch() {
  globalThis.fetch = originalFetch;
}

Deno.test("generateOrderNumber returns 8 numeric digits", () => {
  const value = generateOrderNumber();
  assertEquals(/^\d{8}$/.test(value), true);
});

Deno.test("normalizePaymentMethod accepts revolut aliases", () => {
  assertEquals(normalizePaymentMethod("revolut"), "revolut_link");
  assertEquals(normalizePaymentMethod("revolut-link"), "revolut_link");
  assertEquals(normalizePaymentMethod("revolut_link"), "revolut_link");
  assertEquals(normalizePaymentMethod("cash"), "cash");
  assertThrows(() => normalizePaymentMethod("card"));
});

Deno.test("orderPaymentStatusForMethod maps supported methods", () => {
  assertEquals(orderPaymentStatusForMethod("cash"), "not_required");
  assertEquals(orderPaymentStatusForMethod("revolut_link"), "pending");
  assertEquals(orderPaymentStatusForMethod("momo_ussd"), "pending");
});

Deno.test(
  "normalizeVenueSupportedPaymentMethods defaults to cash with optional revolut",
  () => {
    assertEquals(normalizeVenueSupportedPaymentMethods(undefined), ["cash"]);
    assertEquals(
      normalizeVenueSupportedPaymentMethods(
        undefined,
        "https://revolut.me/test",
      ),
      ["cash", "revolut_link"],
    );
    assertEquals(
      normalizeVenueSupportedPaymentMethods(["cash", "revolut", "cash"]),
      ["cash", "revolut_link"],
    );
  },
);

Deno.test(
  "venueOrderingReadiness requires approval, verification, profile, and payment config",
  () => {
    const readiness = venueOrderingReadiness({
      status: "active",
      ordering_enabled: true,
      supported_payment_methods: ["cash", "revolut_link"],
      approved_claim_id: null,
      approved_at: null,
      access_verified_at: null,
      name: "Test Venue",
      address: "",
      phone: "",
      image_url: null,
      owner_contact_phone: null,
      owner_whatsapp_number: null,
      revolut_url: null,
    });

    assertEquals(readiness.ready, false);
    assertEquals(readiness.supportedPaymentMethods, ["cash"]);
    assertEquals(readiness.reasons.includes("approved_claim_required"), true);
    assertEquals(
      readiness.reasons.includes("access_verification_required"),
      true,
    );
    assertEquals(readiness.reasons.includes("venue_phone_required"), true);
    assertEquals(readiness.reasons.includes("venue_image_required"), true);
    assertEquals(readiness.reasons.includes("owner_contact_required"), true);
    assertEquals(readiness.reasons.includes("revolut_url_required"), false);
  },
);

Deno.test(
  "venueOrderingReadiness blocks closed Google businesses unless override is enabled",
  () => {
    const blocked = venueOrderingReadiness({
      status: "active",
      ordering_enabled: true,
      supported_payment_methods: ["cash"],
      approved_claim_id: "claim-123",
      approved_at: "2026-03-21T09:00:00.000Z",
      access_verified_at: "2026-03-21T09:15:00.000Z",
      name: "Test Venue",
      address: "Valletta",
      phone: "+35699123456",
      image_url: "https://cdn.example.com/venue.png",
      owner_contact_phone: "+35699123456",
      owner_whatsapp_number: "+35699123456",
      google_business_status: "CLOSED_PERMANENTLY",
      google_closed_override_enabled: false,
    });
    assertEquals(blocked.ready, false);
    assertEquals(
      blocked.reasons.includes("google_business_closed_permanently"),
      true,
    );

    const overridden = venueOrderingReadiness({
      status: "active",
      ordering_enabled: true,
      supported_payment_methods: ["cash"],
      approved_claim_id: "claim-123",
      approved_at: "2026-03-21T09:00:00.000Z",
      access_verified_at: "2026-03-21T09:15:00.000Z",
      name: "Test Venue",
      address: "Valletta",
      phone: "+35699123456",
      image_url: "https://cdn.example.com/venue.png",
      owner_contact_phone: "+35699123456",
      owner_whatsapp_number: "+35699123456",
      google_business_status: "CLOSED_PERMANENTLY",
      google_closed_override_enabled: true,
    });
    assertEquals(overridden.ready, true);
    assertEquals(
      overridden.reasons.includes("google_business_closed_permanently"),
      false,
    );
  },
);

Deno.test("buildApprovedClaimUpdate stores durable approval metadata", () => {
  const approvedAt = "2026-03-21T10:00:00.000Z";
  assertEquals(buildApprovedClaimUpdate(approvedAt, "admin-123"), {
    status: "approved",
    reviewed_at: approvedAt,
    approved_at: approvedAt,
    reviewed_by: "admin-123",
  });
});

Deno.test("buildApprovedVenueLinkage links approved claims without forcing owner_id", () => {
  const approvedAt = "2026-03-21T10:00:00.000Z";
  const update = buildApprovedVenueLinkage(
    {
      id: "claim-123",
      contact_phone: "+35699123456",
      whatsapp_number: "+35699123456",
    },
    approvedAt,
  );

  assertEquals(update.approved_claim_id, "claim-123");
  assertEquals(update.approved_at, approvedAt);
  assertEquals(update.owner_contact_phone, "+35699123456");
  assertEquals(update.owner_whatsapp_number, "+35699123456");
  assertFalse("owner_id" in update);
});

Deno.test("venue access audit updates include durable verification fields", () => {
  const issuedAt = "2026-03-21T10:05:00.000Z";
  const verifiedAt = "2026-03-21T10:06:00.000Z";
  assertEquals(
    buildClaimAccessAuditUpdate({
      issuedAt,
      verifiedAt,
      normalizedPhone: "+35699123456",
      challengeId: "7d3c58d1-5a9e-47f4-a028-240c7d5ee111",
      verificationMethod: "otp",
      verifiedBy: "+35699123456",
      verificationNote: "Verified via WhatsApp OTP.",
    }),
    {
      last_access_token_issued_at: issuedAt,
      whatsapp_verified_at: verifiedAt,
      last_verified_whatsapp_number: "+35699123456",
      last_otp_challenge_id: "7d3c58d1-5a9e-47f4-a028-240c7d5ee111",
      access_verification_method: "otp",
      access_verified_by: "+35699123456",
      access_verification_note: "Verified via WhatsApp OTP.",
    },
  );

  assertEquals(
    buildVenueAccessAuditUpdate({
      id: "claim-123",
      venue_id: "venue-123",
      approved_at: "2026-03-21T10:00:00.000Z",
      contact_phone: "+35699123456",
      whatsapp_number: "+35699888777",
    }, {
      issuedAt,
      verifiedAt,
      verificationMethod: "otp",
      verifiedBy: "+35699123456",
      verificationNote: "Verified via WhatsApp OTP.",
    }),
    {
      approved_claim_id: "claim-123",
      approved_at: "2026-03-21T10:00:00.000Z",
      owner_contact_phone: "+35699123456",
      owner_whatsapp_number: "+35699888777",
      last_access_token_issued_at: issuedAt,
      access_verified_at: verifiedAt,
      access_verification_method: "otp",
      access_verified_by: "+35699123456",
      access_verification_note: "Verified via WhatsApp OTP.",
    },
  );
});

Deno.test("sanitizeOrderInsert requires a table number", () => {
  assertThrows(
    () =>
      sanitizeOrderInsert({
        venue_id: "venue-123",
        items: [{ menu_item_id: "item-123", quantity: 1 }],
        payment_method: "cash",
      }),
    Error,
    "Table number is required",
  );
});

Deno.test("sanitizeOrderInsert rejects anonymous user spoofing", () => {
  assertThrows(
    () =>
      sanitizeOrderInsert({
        venue_id: "venue-123",
        user_id: "user-123",
        items: [{ menu_item_id: "item-123", quantity: 1 }],
        payment_method: "cash",
        table_number: "12",
      }),
    Error,
    "Authenticated session required",
  );
});

Deno.test("normalizeWaveTableNumber canonicalizes numeric values", () => {
  assertEquals(normalizeWaveTableNumber(" 04 "), "4");
  assertEquals(normalizeWaveTableNumber(12), "12");
  assertThrows(
    () => normalizeWaveTableNumber("A12"),
    Error,
    "Table number must be 1 to 4 digits",
  );
  assertThrows(
    () => normalizeWaveTableNumber("0000"),
    Error,
    "Table number must be 1 to 4 digits",
  );
});

Deno.test("shouldGenerateAiVenueProfileImage skips only manual or locked images", () => {
  assertEquals(
    shouldGenerateAiVenueProfileImage({
      image_url: null,
      image_source: null,
      image_locked: false,
    }),
    true,
  );
  assertEquals(
    shouldGenerateAiVenueProfileImage({
      image_url: "https://example.com/discovered.jpg",
      image_source: null,
      image_locked: false,
    }),
    true,
  );
  assertEquals(
    shouldGenerateAiVenueProfileImage({
      image_url: "https://example.com/generated.jpg",
      image_source: "ai_gemini",
      image_locked: false,
    }),
    false,
  );
  assertEquals(
    shouldGenerateAiVenueProfileImage({
      image_url: "https://example.com/manual.jpg",
      image_source: "manual",
      image_locked: false,
    }),
    false,
  );
  assertEquals(
    shouldGenerateAiVenueProfileImage({
      image_url: null,
      image_source: null,
      image_locked: true,
    }),
    false,
  );
});

Deno.test("assertValidOrderStatusTransition enforces the dine-in lifecycle", () => {
  assertValidOrderStatusTransition("placed", "received");
  assertValidOrderStatusTransition("received", "served");
  assertThrows(
    () => assertValidOrderStatusTransition("served", "cancelled"),
    Error,
    "Invalid order status transition",
  );
});

Deno.test({
  name: "send_wave - rate limits anonymous request bursts from the same device",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    resetWaveRateLimitState();
    let insertCount = 0;

    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        return new Response(
          JSON.stringify({
            id: "venue-123",
            status: "active",
          }),
          { status: 200 },
        );
      }

      if (req.url.includes("/rest/v1/bell_requests") && req.method === "GET") {
        return new Response("null", {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      if (req.url.includes("/rest/v1/bell_requests") && req.method === "POST") {
        insertCount += 1;
        const payload = await req.json();
        return new Response(
          JSON.stringify({
            id: `wave-${insertCount}`,
            venue_id: payload.venue_id,
            table_number: payload.table_number,
            user_id: payload.user_id ?? null,
            status: "pending",
            created_at: `2026-03-22T10:00:0${insertCount}.000Z`,
          }),
          { status: 201 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const requestHeaders = {
        "Content-Type": "application/json",
        "CF-Connecting-IP": "198.51.100.10",
        "User-Agent": "DineInQA/1.0",
      };

      for (const tableNumber of ["1", "2", "3"]) {
        const req = new Request("http://localhost:8000/", {
          method: "POST",
          headers: requestHeaders,
          body: JSON.stringify({
            action: "send_wave",
            venueId: "venue-123",
            tableNumber,
          }),
        });

        const res = await handleAppRequest(req);
        assertEquals(res.status, 201);
      }

      const blockedReq = new Request("http://localhost:8000/", {
        method: "POST",
        headers: requestHeaders,
        body: JSON.stringify({
          action: "send_wave",
          venueId: "venue-123",
          tableNumber: "4",
        }),
      });

      const blockedRes = await handleAppRequest(blockedReq);
      assertEquals(blockedRes.status, 429);
      const blockedBody = await blockedRes.json();
      assertEquals(blockedBody.code, "wave_rate_limited");
      assertEquals(insertCount, 3);
    } finally {
      restoreFetch();
      resetWaveRateLimitState();
    }
  },
});

Deno.test({
  name: "get_venue_by_slug exposes guest WiFi credentials on venue detail",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        return new Response(
          JSON.stringify({
            id: "venue-123",
            name: "Harbor Table",
            slug: "harbor-table",
            category: "restaurant",
            description: "Seafront dining.",
            address: "Valletta Waterfront",
            status: "active",
            ordering_enabled: true,
            wifi_ssid: "HarborGuest",
            wifi_password: "seaside123",
            wifi_security: "WPA",
          }),
          { status: 200 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "get_venue_by_slug",
          slug: "harbor-table",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(body.data?.wifi_ssid, "HarborGuest");
      assertEquals(body.data?.wifi_password, "seaside123");
      assertEquals(body.data?.wifi_security, "WPA");
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name:
    "search_google_maps rate limits repeated anonymous lookups from the same device",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    resetGoogleMapsSearchRateLimitState();
    Deno.env.set("GEMINI_API_KEY", "test-gemini-key");
    let upstreamCount = 0;

    mockFetch(async (req) => {
      if (req.url.includes("generativelanguage.googleapis.com")) {
        upstreamCount += 1;
        const payload = await req.json();
        const prompt = payload.contents?.[0]?.parts?.[0]?.text as
          | string
          | undefined;
        assertStringIncludes(prompt ?? "", "Country: Malta");

        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text:
                        '[{"name":"Harbor Table","address":"Valletta Waterfront","category":"Restaurants"}]',
                    },
                  ],
                },
              },
            ],
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" },
          },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const requestHeaders = {
        "Content-Type": "application/json",
        "CF-Connecting-IP": "198.51.100.20",
        "User-Agent": "DineInOnboarding/1.0",
      };

      for (let index = 0; index < 20; index += 1) {
        const req = new Request("http://localhost:8000/", {
          method: "POST",
          headers: requestHeaders,
          body: JSON.stringify({
            action: "search_google_maps",
            query: `harbor ${index}`,
            country: "France",
          }),
        });

        const res = await handleAppRequest(req);
        assertEquals(res.status, 200);
      }

      const blockedReq = new Request("http://localhost:8000/", {
        method: "POST",
        headers: requestHeaders,
        body: JSON.stringify({
          action: "search_google_maps",
          query: "harbor blocked",
        }),
      });

      const blockedRes = await handleAppRequest(blockedReq);
      assertEquals(blockedRes.status, 429);
      const blockedBody = await blockedRes.json();
      assertEquals(blockedBody.code, "google_maps_search_rate_limited");
      assertEquals(upstreamCount, 20);
    } finally {
      restoreFetch();
      resetGoogleMapsSearchRateLimitState();
      Deno.env.delete("GEMINI_API_KEY");
    }
  },
});

Deno.test({
  name:
    "get_menu_items - guest only receives available items and hidden prices for browse-only venues",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        return new Response(
          JSON.stringify({
            id: "venue-123",
            name: "Preview Venue",
            status: "active",
            ordering_enabled: false,
          }),
          { status: 200 },
        );
      }

      if (req.url.includes("/rest/v1/dinein_menu_items")) {
        return new Response(
          JSON.stringify([
            {
              id: "item-1",
              venue_id: "venue-123",
              name: "Visible Item",
              description: "Shown to guests",
              category: "Mains",
              price: 14,
              is_available: true,
            },
            {
              id: "item-2",
              venue_id: "venue-123",
              name: "Hidden Item",
              description: "Should disappear for guests",
              category: "Mains",
              price: 18,
              is_available: false,
            },
          ]),
          { status: 200 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "get_menu_items",
          venueId: "venue-123",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);

      const body = await res.json();
      assertEquals(body.data?.length, 1);
      assertEquals(body.data?.[0]?.id, "item-1");
      assertEquals(body.data?.[0]?.price, 0);
      assertEquals(body.data?.[0]?.price_hidden, true);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "set_menu_item_highlights stores ordered guest highlights for a venue",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const updates: Array<{ url: string; body: unknown }> = [];

    mockFetch(async (req) => {
      if (
        req.method === "GET" &&
        req.url.includes("/rest/v1/dinein_menu_items") &&
        req.url.includes("select=id")
      ) {
        return new Response(
          JSON.stringify([{ id: "item-2" }, { id: "item-1" }]),
          { status: 200 },
        );
      }

      if (
        req.method === "PATCH" &&
        req.url.includes("/rest/v1/dinein_menu_items")
      ) {
        updates.push({
          url: req.url,
          body: await req.json(),
        });
        return new Response(JSON.stringify([]), { status: 200 });
      }

      if (
        req.method === "GET" &&
        req.url.includes("/rest/v1/dinein_menu_items") &&
        req.url.includes("select=*")
      ) {
        return new Response(
          JSON.stringify([
            {
              id: "item-2",
              venue_id: "venue-123",
              name: "Chef Pick",
              description: "",
              category: "Mains",
              price: 12,
              highlight_rank: 1,
              is_available: true,
            },
            {
              id: "item-1",
              venue_id: "venue-123",
              name: "Signature Plate",
              description: "",
              category: "Mains",
              price: 14,
              highlight_rank: 2,
              is_available: true,
            },
            {
              id: "item-3",
              venue_id: "venue-123",
              name: "Fallback Plate",
              description: "",
              category: "Mains",
              price: 16,
              highlight_rank: null,
              is_available: true,
            },
          ]),
          { status: 200 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "set_menu_item_highlights",
          venueId: "venue-123",
          itemIds: ["item-2", "item-1"],
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);

      const body = await res.json();
      assertEquals(
        body.data?.map((
          item: { id: string; highlight_rank: number | null },
        ) => [
          item.id,
          item.highlight_rank,
        ]),
        [
          ["item-2", 1],
          ["item-1", 2],
          ["item-3", null],
        ],
      );

      assertEquals(updates.length, 3);
      assertEquals(updates[0].body, { highlight_rank: null });
      assertEquals(
        updates[0].url.includes("venue_id=eq.venue-123"),
        true,
      );
      assertEquals(updates[1].body, { highlight_rank: 1 });
      assertEquals(updates[1].url.includes("id=eq.item-2"), true);
      assertEquals(updates[2].body, { highlight_rank: 2 });
      assertEquals(updates[2].url.includes("id=eq.item-1"), true);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "place_order - rejects revolut orders for venues without a Revolut URL",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        return new Response(
          JSON.stringify({
            id: "venue-123",
            name: "Test Venue",
            status: "active",
            ordering_enabled: true,
            approved_claim_id: "claim-123",
            approved_at: "2026-03-21T09:00:00.000Z",
            access_verified_at: "2026-03-21T09:15:00.000Z",
            address: "Valletta",
            phone: "+35699123456",
            image_url: "https://cdn.example.com/venue.png",
            owner_contact_phone: "+35699123456",
            supported_payment_methods: ["cash", "revolut_link"],
            revolut_url: null,
          }),
          { status: 200 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "place_order",
          order: {
            venue_id: "venue-123",
            items: [{ menu_item_id: "item-123", quantity: 1 }],
            payment_method: "revolut_link",
            table_number: "12",
          },
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 409);
      const body = await res.json();
      assertEquals(body.code, "revolut_unavailable");
      assertStringIncludes(body.error, "has not configured Revolut");
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "place_order - rejects payment methods not enabled for the venue",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        return new Response(
          JSON.stringify({
            id: "venue-123",
            name: "Cash Only Venue",
            status: "active",
            ordering_enabled: true,
            approved_claim_id: "claim-123",
            approved_at: "2026-03-21T09:00:00.000Z",
            access_verified_at: "2026-03-21T09:15:00.000Z",
            address: "Valletta",
            phone: "+35699123456",
            image_url: "https://cdn.example.com/venue.png",
            owner_contact_phone: "+35699123456",
            supported_payment_methods: ["cash"],
            revolut_url: "https://revolut.me/cashonly",
          }),
          { status: 200 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "place_order",
          order: {
            venue_id: "venue-123",
            items: [{ menu_item_id: "item-123", quantity: 1 }],
            payment_method: "revolut_link",
            table_number: "12",
          },
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 409);
      const body = await res.json();
      assertEquals(body.code, "payment_method_unavailable");
      assertEquals(body.supported_payment_methods, ["cash"]);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "update_order_status - rejects invalid served to cancelled transitions",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    let patchAttempted = false;

    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_orders")) {
        if (req.method == "PATCH") {
          patchAttempted = true;
        }
        return new Response(
          JSON.stringify({
            venue_id: "venue-123",
            status: "served",
          }),
          { status: 200 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "update_order_status",
          orderId: "order-123",
          status: "cancelled",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 409);
      const body = await res.json();
      assertEquals(body.code, "invalid_order_transition");
      assertEquals(patchAttempted, false);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "upload_menu_file - rejects unauthenticated requests",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const req = new Request("http://localhost:8000/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "upload_menu_file",
        fileName: "test.pdf",
        contentType: "application/pdf",
        fileData: "YmFzZTY0", // valid base64
      }),
    });

    const res = await handleAppRequest(req);
    assertEquals(res.status, 401);
    const body = await res.json();
    assertStringIncludes(body.error, "Authentication required");
  },
});

Deno.test({
  name: "upload_menu_file - rejects unsupported MIME types",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const req = new Request("http://localhost:8000/", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${serviceRoleJwt}`,
      },
      body: JSON.stringify({
        action: "upload_menu_file",
        fileName: "test.txt",
        contentType: "text/plain",
        fileData: "YmFzZTY0",
      }),
    });

    const res = await handleAppRequest(req);
    assertEquals(res.status, 400);
    const body = await res.json();
    assertStringIncludes(body.error, "Unsupported file type");
  },
});

Deno.test({
  name: "ocr_extract_menu - rejects non-storage URLs",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const req = new Request("http://localhost:8000/", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${serviceRoleJwt}`,
      },
      body: JSON.stringify({
        action: "ocr_extract_menu",
        fileUrl: "https://example.com/malicious.pdf",
      }),
    });

    const res = await handleAppRequest(req);
    assertEquals(res.status, 400);
    const body = await res.json();
    assertStringIncludes(
      body.error,
      "only accepts signed uploads from the menu-uploads bucket",
    );
  },
});

Deno.test({
  name: "approve_claim - fails if claim is not pending",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      // Mock Supabase Auth getUser (called by requireAdmin)
      if (req.url.includes("/auth/v1/user")) {
        return new Response(
          JSON.stringify({
            id: "admin-123",
            role: "authenticated",
          }),
          { status: 200 },
        );
      }

      // Mock PostgREST for requireAdmin role check
      if (req.url.includes("dinein_profiles")) {
        return new Response(
          JSON.stringify([{
            id: "admin-123",
            role: "admin",
          }]),
          { status: 200 },
        );
      }

      // Mock PostgREST for claim fetch
      if (req.url.includes("dinein_venue_claims")) {
        return new Response(
          JSON.stringify({
            id: "claim-123",
            venue_id: "venue-123",
            status: "approved",
          }),
          { status: 200 },
        );
      }

      return new Response(JSON.stringify({}), { status: 200 });
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "approve_claim",
          claimId: "claim-123",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 400);
      const body = await res.json();
      assertStringIncludes(body.error, "Claim is already approved");
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name:
    "confirm_venue_access - service role persists verification and reports readiness",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    let claimAuditUpdate: Record<string, unknown> | null = null;
    let venueAuditUpdate: Record<string, unknown> | null = null;
    const venueRow: Record<string, unknown> = {
      id: "venue-123",
      name: "Ocean Basket",
      status: "active",
      ordering_enabled: false,
      approved_claim_id: "claim-123",
      approved_at: "2026-03-21T09:36:29.781466+00:00",
      access_verified_at: null,
      address: "Valletta",
      phone: "+35699711145",
      image_url: "https://cdn.example.com/venue.png",
      owner_contact_phone: "+35699711145",
      owner_whatsapp_number: "+35699711145",
      supported_payment_methods: ["cash"],
      revolut_url: null,
    };

    mockFetch(async (req) => {
      if (
        req.url.includes("/rest/v1/dinein_venue_claims") &&
        req.method === "GET"
      ) {
        return new Response(
          JSON.stringify([{
            id: "claim-123",
            venue_id: "venue-123",
            claimant_id: null,
            contact_phone: "+35699711145",
            whatsapp_number: "+35699711145",
            status: "approved",
            approved_at: "2026-03-21T09:36:29.781466+00:00",
          }]),
          { status: 200 },
        );
      }

      if (
        req.url.includes("/rest/v1/dinein_venue_claims?id=eq.claim-123") &&
        req.method === "PATCH"
      ) {
        claimAuditUpdate = await req.json();
        return new Response(JSON.stringify([claimAuditUpdate]), {
          status: 200,
        });
      }

      if (
        req.url.includes("/rest/v1/dinein_venues") &&
        req.method === "GET" &&
        req.url.includes("select=name")
      ) {
        return new Response(
          JSON.stringify({ name: venueRow.name }),
          { status: 200 },
        );
      }

      if (
        req.url.includes("/rest/v1/dinein_venues") &&
        req.method === "GET"
      ) {
        return new Response(JSON.stringify(venueRow), { status: 200 });
      }

      if (
        req.url.includes("/rest/v1/dinein_venues?id=eq.venue-123") &&
        req.method === "PATCH"
      ) {
        venueAuditUpdate = await req.json();
        Object.assign(venueRow, venueAuditUpdate);
        return new Response(JSON.stringify([venueRow]), { status: 200 });
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "confirm_venue_access",
          venueId: "venue-123",
          contactPhone: "+35699711145",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      if (!claimAuditUpdate || !venueAuditUpdate) {
        throw new Error("Expected claim and venue audit updates to be sent");
      }
      const claimAudit = claimAuditUpdate as unknown as Record<string, unknown>;
      const venueAudit = venueAuditUpdate as unknown as Record<string, unknown>;
      assertEquals(body.data?.ordering_ready, true);
      assertEquals(body.data?.readiness_reasons, []);
      assertEquals(typeof body.data?.verified_at, "string");
      assertEquals(typeof body.data?.venue_token?.access_token, "string");
      assertEquals(body.data?.verification_method, "admin_override");
      assertEquals(body.data?.verified_by, "service_role");
      assertEquals(claimAudit.whatsapp_verified_at != null, true);
      assertEquals(
        claimAudit.last_verified_whatsapp_number,
        "+35699711145",
      );
      assertEquals(claimAudit.access_verification_method, "admin_override");
      assertEquals(claimAudit.access_verified_by, "service_role");
      assertEquals(
        claimAudit.access_verification_note,
        "Admin confirmed venue access without OTP.",
      );
      assertEquals(venueAudit.access_verified_at != null, true);
      assertEquals(venueAudit.approved_claim_id, "claim-123");
      assertEquals(venueAudit.access_verification_method, "admin_override");
      assertEquals(venueAudit.access_verified_by, "service_role");
      assertEquals(
        venueAudit.access_verification_note,
        "Admin confirmed venue access without OTP.",
      );
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "create_pending_claim_venue - requires contact info",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const req = new Request("http://localhost:8000/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "create_pending_claim_venue",
        // Missing contactPhone and contactEmail
        venueData: { name: "Test Venue" },
      }),
    });

    const res = await handleAppRequest(req);
    assertEquals(res.status, 400);
    const body = await res.json();
    assertStringIncludes(body.error, "Contact phone or email is required");
  },
});

Deno.test({
  name:
    "get_claimable_venues - filters for active unclaimed venues on the server",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    let requestedClaimableFeed = false;

    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        const decodedUrl = decodeURIComponent(req.url);
        requestedClaimableFeed = true;
        assertStringIncludes(decodedUrl, "status=eq.active");
        assertStringIncludes(decodedUrl, "owner_id=is.null");
        assertStringIncludes(decodedUrl, "approved_claim_id=is.null");
        assertStringIncludes(decodedUrl, "name.ilike.%azure%");
        return new Response(
          JSON.stringify([
            {
              id: "venue-123",
              name: "Azure Bar",
              slug: "azure-bar",
              category: "Bar",
              description: "",
              address: "Xlendi Bay, Gozo",
              status: "active",
              rating: 4.1,
              rating_count: 56,
              country: "MT",
            },
          ]),
          { status: 200 },
        );
      }

      return new Response(JSON.stringify({}), { status: 200 });
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "get_claimable_venues",
          query: "azure",
          limit: 5,
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(Array.isArray(body.data), true);
      assertEquals(body.data.length, 1);
      assertEquals(body.data[0].id, "venue-123");
      assertEquals(requestedClaimableFeed, true);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name:
    "search_onboarding_venues - returns blocked match metadata for live claimed venues",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        const decodedUrl = decodeURIComponent(req.url);
        if (decodedUrl.includes("owner_id=is.null")) {
          assertStringIncludes(decodedUrl, "approved_claim_id=is.null");
          return new Response(JSON.stringify([]), { status: 200 });
        }

        if (
          decodedUrl.includes(
            "select=id,name,slug,status,owner_id,approved_claim_id",
          )
        ) {
          return new Response(
            JSON.stringify([
              {
                id: "venue-live-1",
                name: "Azure Bar",
                slug: "azure-bar",
                status: "active",
                owner_id: null,
                approved_claim_id: "claim-123",
              },
            ]),
            { status: 200 },
          );
        }
      }

      return new Response(JSON.stringify({}), { status: 200 });
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "search_onboarding_venues",
          query: "Azure Bar",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(Array.isArray(body.data.results), true);
      assertEquals(body.data.results.length, 0);
      assertEquals(body.data.blockedMatch.name, "Azure Bar");
      assertEquals(body.data.blockedMatch.reason, "already_live");
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name:
    "create_pending_claim_venue - rejects duplicates for already claimed active venues",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    let attemptedInsert = false;

    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues") && req.method === "GET") {
        return new Response(
          JSON.stringify({
            id: "venue-live-1",
            name: "Azure Bar",
            slug: "azure-bar",
            status: "active",
            owner_id: null,
            approved_claim_id: "claim-123",
          }),
          { status: 200 },
        );
      }

      if (req.url.includes("/rest/v1/dinein_venues") && req.method === "POST") {
        attemptedInsert = true;
        return new Response(JSON.stringify({}), { status: 201 });
      }

      return new Response(JSON.stringify({}), { status: 200 });
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "create_pending_claim_venue",
          draft: {
            name: "Azure Bar",
            contact_phone: "+35699123456",
          },
          contactPhone: "+35699123456",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 409);
      const body = await res.json();
      assertStringIncludes(body.error, "already live on DineIn");
      assertEquals(attemptedInsert, false);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "get_venue_notification_settings returns defaults when no row exists",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      if (
        req.url.includes("/rest/v1/dinein_venue_notification_settings") &&
        req.method === "GET"
      ) {
        return new Response("null", {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "get_venue_notification_settings",
          venueId: "venue-123",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(body.data?.order_push_enabled, true);
      assertEquals(body.data?.whatsapp_updates_enabled, true);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name:
    "update_venue_notification_settings persists settings and syncs venue registrations",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    let savedSettings: Record<string, unknown> | null = null;
    let registrationUpdate: Record<string, unknown> | null = null;

    mockFetch(async (req) => {
      if (
        req.url.includes("/rest/v1/dinein_venue_notification_settings") &&
        req.method === "POST"
      ) {
        savedSettings = await req.json();
        return new Response(
          JSON.stringify({
            order_push_enabled: false,
            whatsapp_updates_enabled: true,
          }),
          { status: 201 },
        );
      }

      if (
        req.url.includes("/rest/v1/dinein_push_registrations") &&
        req.method === "PATCH"
      ) {
        registrationUpdate = await req.json();
        return new Response(JSON.stringify([]), { status: 200 });
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "update_venue_notification_settings",
          venueId: "venue-123",
          settings: {
            orderPushEnabled: false,
            whatsAppUpdatesEnabled: true,
          },
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      const saved = (savedSettings ?? {}) as Record<string, unknown>;
      const synced = (registrationUpdate ?? {}) as Record<string, unknown>;
      assertEquals(body.data?.order_push_enabled, false);
      assertEquals(body.data?.whatsapp_updates_enabled, true);
      assertEquals(saved["venue_id"], "venue-123");
      assertEquals(saved["order_push_enabled"], false);
      assertEquals(saved["whatsapp_updates_enabled"], true);
      assertEquals(synced["notifications_enabled"], false);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "register_push_device upserts an authenticated venue push token",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    const cleanupUrls: string[] = [];
    let registrationPayload: Record<string, unknown> | null = null;

    mockFetch(async (req) => {
      if (
        req.url.includes("/rest/v1/dinein_venue_notification_settings") &&
        req.method === "GET"
      ) {
        return new Response(
          JSON.stringify({
            order_push_enabled: true,
            whatsapp_updates_enabled: false,
          }),
          { status: 200 },
        );
      }

      if (
        req.url.includes("/rest/v1/dinein_push_registrations") &&
        req.method === "DELETE"
      ) {
        cleanupUrls.push(decodeURIComponent(req.url));
        return new Response(JSON.stringify([]), { status: 200 });
      }

      if (
        req.url.includes("/rest/v1/dinein_push_registrations") &&
        req.method === "POST"
      ) {
        registrationPayload = await req.json();
        return new Response(
          JSON.stringify({
            id: "reg-123",
            venue_id: "venue-123",
            device_key: "device-1",
            push_token: "a".repeat(64),
            platform: "android",
            notifications_enabled: true,
            last_seen_at: "2026-03-22T12:00:00.000Z",
          }),
          { status: 201 },
        );
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "register_push_device",
          venueId: "venue-123",
          deviceKey: "device-1",
          pushToken: "a".repeat(64),
          platform: "android",
          locale: "en-MT",
          timeZone: "Europe/Malta",
          venue_session: {
            contact_phone: "+35699123456",
          },
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      const saved = (registrationPayload ?? {}) as Record<string, unknown>;
      assertEquals(body.data?.id, "reg-123");
      assertEquals(saved["venue_id"], "venue-123");
      assertEquals(saved["device_key"], "device-1");
      assertEquals(saved["push_token"], "a".repeat(64));
      assertEquals(saved["platform"], "android");
      assertEquals(saved["contact_phone"], "+35699123456");
      assertEquals(saved["notifications_enabled"], true);
      assertEquals(cleanupUrls.length, 2);
      assertEquals(
        cleanupUrls.some((url) => url.includes("push_token=eq.")),
        true,
      );
      assertEquals(
        cleanupUrls.some((url) => url.includes("device_key=eq.device-1")),
        true,
      );
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "unregister_push_device removes the device registration for a venue",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    let deleteUrl: string | null = null;

    mockFetch(async (req) => {
      if (
        req.url.includes("/rest/v1/dinein_push_registrations") &&
        req.method === "DELETE"
      ) {
        deleteUrl = decodeURIComponent(req.url);
        return new Response(JSON.stringify([]), { status: 200 });
      }

      throw new Error(`Unexpected fetch in test: ${req.method} ${req.url}`);
    });

    try {
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "unregister_push_device",
          venueId: "venue-123",
          deviceKey: "device-1",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      assertEquals(deleteUrl == null, false);
      assertStringIncludes(deleteUrl ?? "", "venue_id=eq.venue-123");
      assertStringIncludes(deleteUrl ?? "", "device_key=eq.device-1");
    } finally {
      restoreFetch();
    }
  },
});
