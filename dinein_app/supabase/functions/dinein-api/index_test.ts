import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { handleAppRequest } from "./index.ts";

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
const serviceRoleJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.dummy";

const originalFetch = globalThis.fetch;

// Helper to mock fetch calls if needed by the handler
function mockFetch(handler: (req: Request) => Promise<Response> | Response) {
  globalThis.fetch = async (input: Request | URL | string, init?: RequestInit) => {
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
    assertStringIncludes(body.error, "only accepts signed uploads from the menu-uploads bucket");
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
        return new Response(JSON.stringify({
          id: "admin-123",
          role: "authenticated",
        }), { status: 200 });
      }
      
      // Mock PostgREST for requireAdmin role check
      if (req.url.includes("dinein_profiles")) {
        return new Response(JSON.stringify([{
          id: "admin-123",
          role: "admin"
        }]), { status: 200 });
      }

      // Mock PostgREST for claim fetch
      if (req.url.includes("dinein_venue_claims")) {
        return new Response(JSON.stringify({
          id: "claim-123",
          venue_id: "venue-123",
          status: "approved",
        }), { status: 200 });
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
