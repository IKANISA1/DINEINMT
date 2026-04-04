import { assertEquals } from "jsr:@std/assert@1";

import { handleTrackGuestEvent } from "./core.ts";

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
