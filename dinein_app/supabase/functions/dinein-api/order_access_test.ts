import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { handleGetOrdersForVenue, HttpError } from "./core.ts";

function base64Url(value: string): string {
  return btoa(value).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function serviceRoleRequest(): Request {
  const token = [
    base64Url(JSON.stringify({ alg: "HS256", typ: "JWT" })),
    base64Url(JSON.stringify({ role: "service_role" })),
    "signature",
  ].join(".");

  return new Request("https://example.com/functions/v1/dinein-api", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}

Deno.test("handleGetOrdersForVenue rejects anonymous access before querying orders", async () => {
  const req = new Request("https://example.com/functions/v1/dinein-api", {
    method: "POST",
  });
  const supabase = {
    from() {
      throw new Error("orders query should not run for anonymous requests");
    },
  };

  await assertRejects(
    () =>
      handleGetOrdersForVenue(
        supabase as never,
        req,
        { venueId: "venue-1" },
      ),
    HttpError,
    "Venue access token required.",
  );
});

Deno.test("handleGetOrdersForVenue allows service role access", async () => {
  const req = serviceRoleRequest();
  const calls: string[] = [];
  const supabase = {
    from(table: string) {
      calls.push(table);
      if (table !== "dinein_orders") {
        throw new Error(`unexpected table lookup: ${table}`);
      }

      return {
        select(_selection: string) {
          return {
            eq(column: string, value: string) {
              assertEquals(column, "venue_id");
              assertEquals(value, "venue-1");
              return {
                order(orderColumn: string, options: { ascending: boolean }) {
                  assertEquals(orderColumn, "created_at");
                  assertEquals(options.ascending, false);
                  return Promise.resolve({ data: [], error: null });
                },
              };
            },
          };
        },
      };
    },
  };

  const response = await handleGetOrdersForVenue(
    supabase as never,
    req,
    { venueId: "venue-1" },
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { data: [] });
  assertEquals(calls, ["dinein_orders"]);
});
