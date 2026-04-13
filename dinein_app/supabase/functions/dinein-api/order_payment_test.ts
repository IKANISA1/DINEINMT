import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { HttpError } from "./core.ts";
import { handleMarkOrderPaid } from "./handlers/order.ts";

function serviceRoleRequest(): Request {
  const token = "test-service-role-key";
  Deno.env.set("SERVICE_ROLE_KEY", token);

  return new Request("https://example.com/functions/v1/dinein-api", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}

function buildSupabase({
  order,
  onUpdate,
}: {
  order: Record<string, unknown> | null;
  onUpdate?: (payload: Record<string, unknown>) => void;
}) {
  return {
    from(table: string) {
      assertEquals(table, "dinein_orders");

      return {
        select(_selection: string) {
          return {
            eq(column: string, value: string) {
              assertEquals(column, "id");
              assertEquals(value.startsWith("order-"), true);
              return {
                maybeSingle() {
                  return Promise.resolve({ data: order, error: null });
                },
              };
            },
          };
        },
        update(payload: Record<string, unknown>) {
          onUpdate?.(payload);
          return {
            eq(column: string, value: string) {
              assertEquals(column, "id");
              assertEquals(value.startsWith("order-"), true);
              return Promise.resolve({ error: null });
            },
          };
        },
      };
    },
  };
}

Deno.test("handleMarkOrderPaid confirms unsettled orders", async () => {
  let updatedPayload: Record<string, unknown> | null = null;
  const supabase = buildSupabase({
    order: {
      venue_id: "venue-1",
      status: "served",
      payment_status: "pending",
      payment_method: "revolut_link",
    },
    onUpdate: (payload) => {
      updatedPayload = payload;
    },
  });

  const response = await handleMarkOrderPaid(
    supabase as never,
    serviceRoleRequest(),
    { orderId: "order-1" },
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { data: true });
  assertEquals(updatedPayload?.["payment_status"], "confirmed");
  assertEquals(typeof updatedPayload?.["updated_at"], "string");
});

Deno.test("handleMarkOrderPaid skips updates when the order is already paid", async () => {
  let updateCalls = 0;
  const supabase = buildSupabase({
    order: {
      venue_id: "venue-1",
      status: "served",
      payment_status: "confirmed",
      payment_method: "cash",
    },
    onUpdate: () => {
      updateCalls += 1;
    },
  });

  const response = await handleMarkOrderPaid(
    supabase as never,
    serviceRoleRequest(),
    { orderId: "order-2" },
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { data: true });
  assertEquals(updateCalls, 0);
});

Deno.test("handleMarkOrderPaid blocks cancelled orders", async () => {
  const supabase = buildSupabase({
    order: {
      venue_id: "venue-1",
      status: "cancelled",
      payment_status: "not_required",
      payment_method: "cash",
    },
  });

  await assertRejects(
    () =>
      handleMarkOrderPaid(
        supabase as never,
        serviceRoleRequest(),
        { orderId: "order-3" },
      ),
    HttpError,
    "Cancelled orders cannot be marked as paid.",
  );
});

Deno.test("handleMarkOrderPaid derives legacy missing payment status from payment method", async () => {
  let updatedPayload: Record<string, unknown> | null = null;
  const supabase = buildSupabase({
    order: {
      venue_id: "venue-1",
      status: "received",
      payment_method: "cash",
    },
    onUpdate: (payload) => {
      updatedPayload = payload;
    },
  });

  const response = await handleMarkOrderPaid(
    supabase as never,
    serviceRoleRequest(),
    { orderId: "order-4" },
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { data: true });
  assertEquals(updatedPayload?.["payment_status"], "confirmed");
});
