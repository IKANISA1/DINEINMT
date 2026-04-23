import { assertEquals } from "jsr:@std/assert@1";

import {
  buildNewOrderPushNotification,
  configuredAdminUserIdForSessionPhone,
} from "./core.ts";
import { handleTrackGuestEvent } from "./handlers/telemetry.ts";

function buildSupabaseStub(error: Record<string, unknown> | null) {
  return {
    from(table: string) {
      assertEquals(table, "dinein_guest_analytics_events");
      return {
        insert: async (payload: Record<string, unknown>) => {
          assertEquals(payload.event_name, "discover_viewed");
          assertEquals(payload.session_id, "session-1");
          assertEquals(payload.country, "RW");
          return { error };
        },
      };
    },
  };
}

Deno.test("handleTrackGuestEvent returns 201 when analytics insert succeeds", async () => {
  const req = new Request("https://example.com/discover", {
    headers: {
      "user-agent": "deno-test",
      "referer": "https://dineinrwg.ikanisa.com/discover",
    },
  });

  const response = await handleTrackGuestEvent(
    buildSupabaseStub(null) as never,
    req,
    {
      action: "track_guest_event",
      country: "rw",
      event_name: "discover_viewed",
      session_id: "session-1",
      route: "/discover",
      details: { source: "test" },
    },
  );

  assertEquals(response.status, 201);
  assertEquals(await response.json(), { data: true });
});

Deno.test(
  "handleTrackGuestEvent returns 202 instead of surfacing telemetry failures",
  async () => {
    const req = new Request("https://example.com/discover", {
      headers: {
        "user-agent": "deno-test",
      },
    });

    const response = await handleTrackGuestEvent(
      buildSupabaseStub({ message: "relation does not exist" }) as never,
      req,
      {
        action: "track_guest_event",
        country: "rw",
        event_name: "discover_viewed",
        session_id: "session-1",
        route: "/discover",
      },
    );

    assertEquals(response.status, 202);
    assertEquals(await response.json(), { data: false });
  },
);

Deno.test("configuredAdminUserIdForSessionPhone recognizes configured fallback admin numbers", () => {
  assertEquals(
    configuredAdminUserIdForSessionPhone("+25075588248"),
    "00000000-0000-0000-0000-000000000250",
  );
  assertEquals(
    configuredAdminUserIdForSessionPhone("+35699711145"),
    "00000000-0000-0000-0000-000000000356",
  );
  assertEquals(configuredAdminUserIdForSessionPhone("+35699900000"), null);
});

Deno.test("buildNewOrderPushNotification formats Malta totals in EUR", () => {
  const payload = buildNewOrderPushNotification(
    {
      id: "order-1",
      venue_id: "venue-1",
      order_number: "12345",
      table_number: "7",
      total: 18.5,
      items: [{ quantity: 2 }, { quantity: 1 }],
    },
    "MT",
  );

  assertEquals(payload.title, "New order for table 7");
  assertEquals(payload.body, "Order 12345 - 3 items - EUR 18.50");
});

Deno.test("buildNewOrderPushNotification formats Rwanda totals in RWF", () => {
  const payload = buildNewOrderPushNotification(
    {
      id: "order-2",
      venue_id: "venue-2",
      order_number: "54321",
      table_number: "4",
      total: 12345.67,
      items: [{ quantity: 1 }],
    },
    "RW",
  );

  assertEquals(payload.title, "New order for table 4");
  assertEquals(payload.body, "Order 54321 - 1 item - RWF 12,346");
});
