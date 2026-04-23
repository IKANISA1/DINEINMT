// ─── DineIn API Edge Function (orders-api) ─────────────────────────────
// Slim dispatch entry point. Handler logic lives in handlers/*.ts → core.ts.
// ────────────────────────────────────────────────────────────────────────────
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  applyCorsHeaders,
  assertAllowedAppOrigin,
  buildResponseHeaders,
} from "../_shared/http.ts";

// ─── Core infrastructure ───────────────────────────────────────────────────
import {
  adminClient,
  asRecord,
  fail,
  HttpError,
  ok,
  parseBody,
  requireString,
} from "../_shared/core-monolith.ts";

// ─── Domain handlers ───────────────────────────────────────────────────────
import {
  handleGetAdminDashboardKpis,
  handleGetAllOrders,
  handleGetOrderById,
  handleGetOrdersForUser,
  handleGetOrdersForVenue,
  handleIssueOrderRealtimeAccess,
  handleMarkOrderPaid,
  handlePlaceOrder,
  handleUpdateOrderStatus
} from "./handlers/order.ts";

// ─── Main dispatch ─────────────────────────────────────────────────────────
export async function handleAppRequest(req: Request): Promise<Response> {
  let allowedOrigin: string | null = null;
  let action = "unknown";

  try {
    allowedOrigin = assertAllowedAppOrigin(req);
    if (req.method == "OPTIONS") {
      return new Response("ok", {
        headers: buildResponseHeaders(allowedOrigin, {
          fallbackWildcard: false,
        }),
      });
    }

    const body = await parseBody(req);
    action = requireString(body, "action");
    let supabase: ReturnType<typeof adminClient> | null = null;
    const getSupabase = () => (supabase ??= adminClient());

    const response = await (async () => {
      switch (action) {
case "get_orders_for_venue":
          return await handleGetOrdersForVenue(getSupabase(), req, body);
case "get_orders_for_user":
          return await handleGetOrdersForUser(getSupabase(), req, body);
case "get_all_orders":
          return await handleGetAllOrders(getSupabase(), req);
case "get_admin_dashboard_kpis":
          return await handleGetAdminDashboardKpis(getSupabase(), req, body);
case "get_order_by_id":
          return await handleGetOrderById(getSupabase(), req, body);
case "issue_order_realtime_access":
          return await handleIssueOrderRealtimeAccess(getSupabase(), req, body);
case "update_order_status":
          return await handleUpdateOrderStatus(getSupabase(), req, body);
case "mark_order_paid":
          return await handleMarkOrderPaid(getSupabase(), req, body);
case "place_order":
          return await handlePlaceOrder(getSupabase(), req, body);
        default:
          throw new HttpError(400, `Unsupported action: ${action}`);
      }
    })();

    return applyCorsHeaders(response, allowedOrigin, {
      fallbackWildcard: false,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return applyCorsHeaders(
        fail(error.message, error.status, error.details),
        allowedOrigin,
        { fallbackWildcard: false },
      );
    }

    console.error(`[${action}] Unhandled exception:`, error);
    return applyCorsHeaders(fail("Internal Server Error", 500), allowedOrigin, {
      fallbackWildcard: false,
    });
  }
}

if (import.meta.main) {
  Deno.serve(handleAppRequest);
}
