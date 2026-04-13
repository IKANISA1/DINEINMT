import { assertEquals } from "jsr:@std/assert@1";

import { handleGetVenues } from "./handlers/venue.ts";

function buildVenueSupabaseStub(rows: unknown[]) {
  return {
    from(table: string) {
      assertEquals(table, "dinein_venues");
      return {
        select(selection: string) {
          assertEquals(selection, "*");
          return this;
        },
        eq(column: string, value: string) {
          assertEquals(column, "country");
          assertEquals(value, "MT");
          return Promise.resolve({ data: rows, error: null });
        },
      };
    },
  };
}

Deno.test("handleGetVenues returns summary payload for visible guest venues", async () => {
  const response = await handleGetVenues(
    buildVenueSupabaseStub([
      {
        id: "venue-1",
        country: "MT",
        status: "active",
        name: "Alpha Bistro",
        slug: "alpha-bistro",
        address: "Valletta",
        category: "restaurant",
        description: "Seasonal menu",
        ordering_enabled: true,
        supported_payment_methods: ["cash"],
        rating: 4.8,
        rating_count: 14,
      },
      {
        id: "venue-2",
        country: "MT",
        status: "maintenance",
        name: "Beta Cafe",
        slug: "beta-cafe",
        address: "Sliema",
        category: "cafe",
        description: "Pastries",
        ordering_enabled: false,
        supported_payment_methods: ["cash"],
        rating: 4.6,
        rating_count: 9,
      },
      {
        id: "venue-3",
        country: "MT",
        status: "deleted",
        name: "Hidden Venue",
        slug: "hidden-venue",
        address: "Msida",
        category: "bar",
        description: "Should not surface",
        ordering_enabled: true,
        supported_payment_methods: ["cash"],
      },
    ]) as never,
    {
      country: "mt",
      include_summary: true,
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.data.total_count, 2);
  assertEquals(payload.data.categories, ["cafe", "restaurant"]);
  assertEquals(payload.data.items.length, 2);
  assertEquals(payload.data.items[0].id, "venue-1");
  assertEquals(payload.data.items[1].id, "venue-2");
});
