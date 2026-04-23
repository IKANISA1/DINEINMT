import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handleAppRequest as handleAdminApiRequest } from "./admin-api/index.ts";
import { handleAppRequest as handleCoreApiRequest } from "./core-api/index.ts";
import { handleAppRequest as handleMenuApiRequest } from "./menu-api/index.ts";
import { handleAppRequest as handleOrdersApiRequest } from "./orders-api/index.ts";
import { handleAppRequest as handleVenueApiRequest } from "./venue-api/index.ts";

type EntryPointCase = {
  name: string;
  handler: (req: Request) => Promise<Response>;
};

const allowedOrigin = "https://dineinmt.ikanisa.com";

const entrypoints: EntryPointCase[] = [
  { name: "core-api", handler: handleCoreApiRequest },
  { name: "orders-api", handler: handleOrdersApiRequest },
  { name: "menu-api", handler: handleMenuApiRequest },
  { name: "venue-api", handler: handleVenueApiRequest },
  { name: "admin-api", handler: handleAdminApiRequest },
];

function buildJsonRequest(body: Record<string, unknown>): Request {
  return new Request("http://127.0.0.1/functions/v1/test", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      origin: allowedOrigin,
    },
    body: JSON.stringify(body),
  });
}

for (const entrypoint of entrypoints) {
  Deno.test(`${entrypoint.name} returns 400 for unsupported actions`, async () => {
    const response = await entrypoint.handler(
      buildJsonRequest({ action: "__unsupported_action__" }),
    );

    assertEquals(response.status, 400);
    assertEquals(
      response.headers.get("access-control-allow-origin"),
      allowedOrigin,
    );

    const payload = await response.json();
    assertEquals(
      payload,
      { error: "Unsupported action: __unsupported_action__" },
    );
  });

  Deno.test(`${entrypoint.name} responds to allowed preflight requests`, async () => {
    const response = await entrypoint.handler(
      new Request("http://127.0.0.1/functions/v1/test", {
        method: "OPTIONS",
        headers: { origin: allowedOrigin },
      }),
    );

    assertEquals(response.status, 200);
    assertEquals(
      response.headers.get("access-control-allow-origin"),
      allowedOrigin,
    );
  });
}

Deno.test("core-api health endpoint returns the expected payload", async () => {
  const response = await handleCoreApiRequest(buildJsonRequest({ action: "health" }));

  assertEquals(response.status, 200);
  assertEquals(
    response.headers.get("access-control-allow-origin"),
    allowedOrigin,
  );
  assertEquals(await response.json(), { data: { ok: true } });
});
