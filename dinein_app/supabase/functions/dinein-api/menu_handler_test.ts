import { assertRejects } from "jsr:@std/assert@1";

import { handleSetMenuItemHighlights } from "./handlers/menu.ts";
import { HttpError } from "./core.ts";

Deno.test("handleSetMenuItemHighlights rejects more than three highlighted items", async () => {
  Deno.env.set("SERVICE_ROLE_KEY", "test-service-role-key");
  const req = new Request("https://example.com", {
    headers: { Authorization: "Bearer test-service-role-key" },
  });

  await assertRejects(
    () =>
      handleSetMenuItemHighlights(
        {
          from() {
            throw new Error("database should not be queried");
          },
        } as never,
        req,
        {
          venue_id: "venue-1",
          item_ids: ["1", "2", "3", "4"],
        },
      ),
    HttpError,
    "You can select at most 3 highlighted items.",
  );
});
