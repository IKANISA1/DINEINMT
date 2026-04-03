import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import {
  assertValidOrderStatusTransition,
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
Deno.env.set("GEMINI_API_KEY", "mock-gemini-key");
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
  "venueOrderingReadiness requires verification, profile, and payment config",
  () => {
    const readiness = venueOrderingReadiness({
      status: "active",
      ordering_enabled: true,
      supported_payment_methods: ["cash", "revolut_link"],
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
    assertEquals(
      readiness.reasons.includes("access_verification_required"),
      true,
    );
    assertEquals(readiness.reasons.includes("venue_phone_required"), true);
    assertEquals(readiness.reasons.includes("venue_image_required"), true);
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
  name: "search_google_maps scopes the prompt to Rwanda when requested",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    resetGoogleMapsSearchRateLimitState();
    Deno.env.set("GEMINI_API_KEY", "test-gemini-key");

    mockFetch(async (req) => {
      if (req.url.includes("generativelanguage.googleapis.com")) {
        const payload = await req.json();
        const prompt = payload.contents?.[0]?.parts?.[0]?.text as
          | string
          | undefined;
        assertStringIncludes(prompt ?? "", "Country: Rwanda");

        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text:
                        '[{"name":"Kigali Table","address":"Kigali","category":"Restaurants"}]',
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
      const req = new Request("http://localhost:8000/", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "CF-Connecting-IP": "198.51.100.21",
          "User-Agent": "DineInOnboarding/1.0",
        },
        body: JSON.stringify({
          action: "search_google_maps",
          query: "kigali dinner",
          country: "RW",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(Array.isArray(body.data), true);
      assertEquals(body.data.length, 1);
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
  name: "get_admin_menu_queue aggregates menu review state by venue",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    mockFetch(async (req) => {
      if (req.url.includes("/auth/v1/user")) {
        return new Response(
          JSON.stringify({
            id: "admin-1",
            email: "admin@example.com",
          }),
          { status: 200 },
        );
      }

      if (req.url.includes("/rest/v1/dinein_profiles")) {
        return new Response(
          JSON.stringify({
            id: "admin-1",
            role: "admin",
          }),
          { status: 200 },
        );
      }

      if (req.url.includes("/rest/v1/dinein_menu_items")) {
        return new Response(
          JSON.stringify([
            {
              venue_id: "venue-1",
              category: "Mains",
              is_available: true,
              menu_context_status: "pending",
              updated_at: "2026-04-03T09:00:00.000Z",
              venue: {
                id: "venue-1",
                name: "Harbor Table",
                image_url: "https://cdn.example.com/harbor.png",
                address: "Valletta Waterfront",
                category: "restaurant",
                status: "active",
              },
            },
            {
              venue_id: "venue-1",
              category: "Desserts",
              is_available: false,
              menu_context_status: "ready",
              updated_at: "2026-04-03T08:00:00.000Z",
              venue: {
                id: "venue-1",
                name: "Harbor Table",
                image_url: "https://cdn.example.com/harbor.png",
                address: "Valletta Waterfront",
                category: "restaurant",
                status: "active",
              },
            },
            {
              venue_id: "venue-2",
              category: "Drinks",
              is_available: true,
              menu_context_status: "ready",
              updated_at: "2026-04-02T12:00:00.000Z",
              venue: {
                id: "venue-2",
                name: "Skyline Lounge",
                image_url: null,
                address: "Sliema",
                category: "bar",
                status: "inactive",
              },
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
          action: "get_admin_menu_queue",
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);

      const body = await res.json();
      assertEquals(body.data?.length, 2);
      assertEquals(body.data?.[0]?.venue_id, "venue-1");
      assertEquals(body.data?.[0]?.total_items, 2);
      assertEquals(body.data?.[0]?.available_items, 1);
      assertEquals(body.data?.[0]?.pending_review_count, 1);
      assertEquals(body.data?.[0]?.failed_review_count, 0);
      assertEquals(body.data?.[0]?.ready_count, 1);
      assertEquals(body.data?.[0]?.category_count, 2);
      assertEquals(body.data?.[1]?.venue_id, "venue-2");
      assertEquals(body.data?.[1]?.ready_count, 1);
    } finally {
      restoreFetch();
    }
  },
});

Deno.test({
  name: "audit_menu_item_images reports verifier mismatches for live images",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    Deno.env.set("GEMINI_API_KEY", "test-gemini-key");
    mockFetch(async (req) => {
      if (
        req.method === "GET" &&
        req.url.includes("/rest/v1/dinein_menu_items")
      ) {
        return new Response(
          JSON.stringify([
            {
              id: "item-whisky",
              venue_id: "venue-1",
              name: "Blue Label",
              description: "Aged whisky served neat.",
              category: "Whisky",
              class: "drinks",
              menu_context: {
                class: "drinks",
                confidence: 0.96,
                canonical_name: "Blue Label",
                canonical_category: "Whisky",
                canonical_description: "Aged whisky served neat.",
                visual_subject: "A premium whisky serve",
                serving_style: "Neat pour in a short tumbler",
                visual_directions: [],
                visual_do_not: [],
                keyword_signals: ["whisky"],
                source_queries: [],
                source_urls: [],
                research_summary: "Premium whisky.",
              },
              menu_context_status: "ready",
              menu_context_error: null,
              menu_context_model: "gemini",
              menu_context_attempts: 1,
              menu_context_locked: false,
              menu_context_updated_at: "2026-04-03T09:00:00.000Z",
              image_url: "https://cdn.example.com/item-whisky.png",
              image_source: "ai_gemini",
              image_status: "ready",
              image_model: "gemini-image",
              image_prompt:
                "This item is classified as: drinks\nVisual kind: spirits",
              image_error: null,
              image_attempts: 1,
              image_locked: false,
              image_storage_path: null,
              tags: [],
            },
          ]),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
              "Content-Range": "0-0/1",
            },
          },
        );
      }

      if (req.method === "GET" && req.url.includes("/rest/v1/dinein_venues")) {
        return new Response(
          JSON.stringify({
            id: "venue-1",
            name: "Harbor Lounge",
            category: "bar",
            description: "Cocktails and spirits",
            owner_id: "owner-1",
          }),
          { status: 200 },
        );
      }

      if (
        req.method === "GET" &&
        req.url === "https://cdn.example.com/item-whisky.png"
      ) {
        return new Response(new Uint8Array([137, 80, 78, 71]), {
          status: 200,
          headers: {
            "Content-Type": "image/png",
          },
        });
      }

      if (
        req.method === "POST" &&
        req.url.includes("generativelanguage.googleapis.com")
      ) {
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text:
                        '{"matches":false,"observed_class":"food","reason":"The image shows a plated dish instead of a spirit serve."}',
                    },
                  ],
                },
              },
            ],
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
          Authorization: `Bearer ${serviceRoleJwt}`,
        },
        body: JSON.stringify({
          action: "audit_menu_item_images",
          limit: 5,
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 200);

      const body = await res.json();
      assertEquals(body.data?.total_count, 1);
      assertEquals(body.data?.summary?.mismatch_count, 1);
      assertEquals(body.data?.summary?.needs_regeneration_count, 1);
      assertEquals(body.data?.items?.[0]?.itemId, "item-whisky");
      assertEquals(body.data?.items?.[0]?.auditStatus, "mismatch");
      assertEquals(
        body.data?.items?.[0]?.issues?.some((
          issue: { code: string },
        ) => issue.code === "image_verification_mismatch"),
        true,
      );
    } finally {
      restoreFetch();
      Deno.env.delete("GEMINI_API_KEY");
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
  name: "update_venue rejects duplicate venue access numbers before patching",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn() {
    let patchAttempted = false;

    mockFetch(async (req) => {
      if (req.url.includes("/rest/v1/dinein_venues")) {
        if (
          req.method == "GET" &&
          req.url.includes("normalized_access_phone=eq.%2B35699222333")
        ) {
          return new Response(
            JSON.stringify([
              {
                id: "venue-999",
                name: "Other Venue",
                status: "active",
              },
            ]),
            { status: 200 },
          );
        }

        if (req.method == "GET" && req.url.includes("id=eq.venue-123")) {
          return new Response(
            JSON.stringify({
              id: "venue-123",
              name: "Test Venue",
              status: "active",
              ordering_enabled: false,
              access_verified_at: "2026-04-02T08:05:00.000Z",
              phone: "+35699123456",
              normalized_access_phone: "+35699123456",
              owner_contact_phone: "+35699123456",
              owner_whatsapp_number: "+35699123456",
              address: "Valletta",
              image_url: "https://cdn.example.com/venue.png",
              supported_payment_methods: ["cash"],
            }),
            { status: 200 },
          );
        }

        if (req.method == "PATCH") {
          patchAttempted = true;
          return new Response(JSON.stringify({}), { status: 200 });
        }
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
          action: "update_venue",
          venueId: "venue-123",
          updates: {
            phone: "+35699222333",
          },
        }),
      });

      const res = await handleAppRequest(req);
      assertEquals(res.status, 409);

      const body = await res.json();
      assertEquals(body.code, "venue_access_phone_in_use");
      assertEquals(body.conflicting_venue_id, "venue-999");
      assertEquals(body.conflicting_venue_name, "Other Venue");
      assertEquals(patchAttempted, false);
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
