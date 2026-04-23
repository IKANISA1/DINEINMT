import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

type ExpectedDispatch = {
  entrypoint: string;
  actions: string[];
};

const expectedDispatches: ExpectedDispatch[] = [
  {
    entrypoint: "core-api/index.ts",
    actions: [
      "health",
      "create_profile",
      "get_user_role",
      "track_guest_event",
    ],
  },
  {
    entrypoint: "orders-api/index.ts",
    actions: [
      "get_orders_for_venue",
      "get_orders_for_user",
      "get_all_orders",
      "get_admin_dashboard_kpis",
      "get_order_by_id",
      "issue_order_realtime_access",
      "update_order_status",
      "mark_order_paid",
      "place_order",
    ],
  },
  {
    entrypoint: "menu-api/index.ts",
    actions: [
      "get_menu_items",
      "get_menu_item_by_id",
      "toggle_menu_item_availability",
      "create_menu_item",
      "update_menu_item",
      "delete_menu_item",
      "set_menu_item_highlights",
      "ingest_menu_document",
      "generate_menu_item_image",
      "backfill_menu_images",
      "audit_menu_item_images",
      "upload_menu_item_image",
      "image_health",
    ],
  },
  {
    entrypoint: "venue-api/index.ts",
    actions: [
      "get_venues",
      "get_all_venues",
      "create_venue",
      "get_venue_by_slug",
      "get_venue_by_id",
      "get_venue_for_owner",
      "update_venue",
      "enrich_venue_profile",
      "backfill_venue_profiles",
      "generate_venue_profile_image",
      "backfill_venue_profile_images",
      "get_venue_notification_settings",
      "update_venue_notification_settings",
      "register_push_device",
      "unregister_push_device",
      "send_wave",
      "get_bell_requests",
      "resolve_bell_request",
      "search_google_maps",
      "upload_venue_image",
    ],
  },
  {
    entrypoint: "admin-api/index.ts",
    actions: [
      "get_admin_menu_queue",
      "get_admin_menu_catalog",
      "get_admin_menu_group_assignments",
      "create_admin_menu_groups",
      "assign_admin_menu_group",
      "delete_admin_menu_group",
    ],
  },
];

function dispatchedActions(source: string): string[] {
  return [...source.matchAll(/case "([^"]+)":/g)].map((match) => match[1]);
}

function sortedActions(actions: string[]): string[] {
  return [...actions].sort();
}

for (const expected of expectedDispatches) {
  Deno.test(`${expected.entrypoint} pins its split action ownership`, async () => {
    const source = await Deno.readTextFile(new URL(expected.entrypoint, import.meta.url));
    assertEquals(dispatchedActions(source), expected.actions);
  });
}

Deno.test("split edge-function action ownership stays disjoint", async () => {
  const owners = new Map<string, string>();

  for (const expected of expectedDispatches) {
    const source = await Deno.readTextFile(
      new URL(expected.entrypoint, import.meta.url),
    );
    for (const action of dispatchedActions(source)) {
      const previousOwner = owners.get(action);
      assertFalse(
        previousOwner != null,
        `Action "${action}" is dispatched by both ${previousOwner} and ${expected.entrypoint}.`,
      );
      owners.set(action, expected.entrypoint);
    }
  }
});

Deno.test(
  "legacy dinein-api compatibility dispatcher stays aligned with split action ownership",
  async () => {
    const legacySource = await Deno.readTextFile(
      new URL("dinein-api/index.ts", import.meta.url),
    );
    const legacyActions = sortedActions(dispatchedActions(legacySource));
    const splitActions = sortedActions(
      expectedDispatches.flatMap((entry) => entry.actions),
    );

    assertEquals(legacyActions, splitActions);
  },
);
