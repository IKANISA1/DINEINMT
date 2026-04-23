import {
  adminClient,
  adminUserId,
  asRecord,
  assertValidOrderStatusTransition,
  authorizeVenueMutation,
  booleanValue,
  buildNewOrderPushNotification,
  canVenueAcceptGuestOrders,
  currentUser,
  dispatchVenueOperationalAlert,
  dispatchVenueWhatsAppAlert,
  HttpError,
  issueOrderReceiptToken,
  issueScopedRealtimeAccessToken,
  type JsonRecord,
  ok,
  orderPaymentStatusForMethod,
  orderStatusSnapshot,
  requireAdmin,
  requireSelfOrAdmin,
  requireString,
  roundCurrency,
  sanitizeOrderInsert,
  uniqueOrderInsert,
  venueSessionClaims,
  venueSnapshot,
  venueSupportedPaymentMethods,
  verifyOrderReceiptToken,
} from "../../_shared/core-monolith.ts";
import { numberValue, stringValue } from "../../_shared/env.ts";

type SanitizedOrderItemInput = {
  menuItemId: string;
  quantity: number;
  note: string | null;
};

async function attachPresentationDataToOrders(
  supabase: ReturnType<typeof adminClient>,
  orders: unknown[],
): Promise<JsonRecord[]> {
  const normalizedOrders = orders.map((order) => asRecord(order));
  const venueIds = [
    ...new Set(
      normalizedOrders
        .map((order) => stringValue(order.venue_id))
        .filter((value): value is string => Boolean(value)),
    ),
  ];
  const menuItemIds = [
    ...new Set(
      normalizedOrders.flatMap((order) => {
        if (!Array.isArray(order.items)) {
          return [];
        }
        return order.items
          .map((rawItem) => {
            const item = asRecord(rawItem);
            return stringValue(item.menu_item_id) ??
              stringValue(item.menuItemId);
          })
          .filter((value): value is string => Boolean(value));
      }),
    ),
  ];

  if (venueIds.length == 0 && menuItemIds.length == 0) {
    return normalizedOrders;
  }

  const imageByVenueId = new Map<string, string | null>();
  if (venueIds.length > 0) {
    const { data, error } = await supabase
      .from("dinein_venues")
      .select("id, image_url")
      .in("id", venueIds);

    if (error) {
      console.error("[orders-api] order venue image lookup failed", error);
    } else {
      for (const entry of (data ?? [])) {
        const venue = asRecord(entry);
        const venueId = stringValue(venue.id);
        if (!venueId) continue;
        imageByVenueId.set(venueId, stringValue(venue.image_url) ?? null);
      }
    }
  }

  const menuById = new Map<string, JsonRecord>();
  if (menuItemIds.length > 0) {
    const { data, error } = await supabase
      .from("dinein_menu_items")
      .select("id, name, description, image_url, price")
      .in("id", menuItemIds);

    if (error) {
      console.error(
        "[orders-api] order item presentation lookup failed",
        error,
      );
    } else {
      for (const entry of (data ?? [])) {
        const menuItem = asRecord(entry);
        const menuItemId = stringValue(menuItem.id);
        if (!menuItemId) continue;
        menuById.set(menuItemId, menuItem);
      }
    }
  }

  return normalizedOrders.map((order) => {
    const venueId = stringValue(order.venue_id);
    const hydratedItems = Array.isArray(order.items)
      ? order.items.map((rawItem) => {
        const item = asRecord(rawItem);
        const menuItemId = stringValue(item.menu_item_id) ??
          stringValue(item.menuItemId);
        const menuItem = menuItemId == null ? null : menuById.get(menuItemId);
        if (menuItem == null) {
          return item;
        }

        const existingDescription = stringValue(item.description) ??
          stringValue(item.menu_item_description);
        const normalizedDescription = existingDescription?.trim();
        const existingImageUrl = stringValue(item.image_url) ??
          stringValue(item.imageUrl) ??
          stringValue(item.menu_item_image_url);
        const normalizedImageUrl = existingImageUrl?.trim();
        const existingName = stringValue(item.name)?.trim();

        return {
          ...item,
          name: existingName != null && existingName.length > 0
            ? existingName
            : stringValue(menuItem.name) ?? "Menu Item",
          description: normalizedDescription != null &&
              normalizedDescription.length > 0
            ? normalizedDescription
            : stringValue(menuItem.description) ?? "",
          image_url: normalizedImageUrl != null && normalizedImageUrl.length > 0
            ? normalizedImageUrl
            : stringValue(menuItem.image_url) ?? null,
          price: numberValue(item.price) ??
            numberValue(menuItem.price) ??
            0,
        };
      })
      : order.items;

    return {
      ...order,
      venue_image_url: venueId == null
        ? stringValue(order.venue_image_url) ?? null
        : imageByVenueId.get(venueId) ??
          stringValue(order.venue_image_url) ??
          null,
      items: hydratedItems,
    };
  });
}

const orderStatuses = new Set(["placed", "received", "served", "cancelled"]);

// Order handlers — order lifecycle
// Actions: place_order, get_orders_for_venue, get_orders_for_user,
//          get_all_orders, get_order_by_id, update_order_status, mark_order_paid
export async function handlePlaceOrder(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const user = await currentUser(req);
  const order = sanitizeOrderInsert(body.order, user?.id);
  const venueId = requireString(order, "venue_id");
  const requestedItems =
    (order.items as SanitizedOrderItemInput[] | undefined) ?? [];

  const venue = await venueSnapshot(supabase, venueId);

  if (!canVenueAcceptGuestOrders(venue)) {
    throw new HttpError(
      409,
      "This venue is unavailable for guest ordering right now.",
      { code: "venue_unavailable" },
    );
  }

  if (
    stringValue(order.payment_method) == "revolut_link" &&
    !stringValue(venue.revolut_url)
  ) {
    throw new HttpError(
      409,
      "This venue has not configured Revolut payments yet.",
      { code: "revolut_unavailable" },
    );
  }

  const supportedPaymentMethods = venueSupportedPaymentMethods(venue);
  if (
    !supportedPaymentMethods.includes(stringValue(order.payment_method) ?? "")
  ) {
    throw new HttpError(
      409,
      "This venue does not support the selected payment method.",
      {
        code: "payment_method_unavailable",
        supported_payment_methods: supportedPaymentMethods,
      },
    );
  }

  const uniqueItemIds = [
    ...new Set(requestedItems.map((item) => item.menuItemId)),
  ];
  const { data: menuData, error: menuError } = await supabase
    .from("dinein_menu_items")
    .select("id, venue_id, name, description, image_url, price, is_available")
    .eq("venue_id", venueId)
    .in("id", uniqueItemIds);

  if (menuError) {
    console.error("[orders-api] place order menu lookup failed", menuError);
    throw new HttpError(500, "Could not validate the requested menu items.");
  }

  const menuById = new Map<string, JsonRecord>();
  for (const item of (menuData ?? [])) {
    const record = asRecord(item);
    const itemId = stringValue(record.id);
    if (itemId) {
      menuById.set(itemId, record);
    }
  }

  const normalizedItems = requestedItems.map((item) => {
    const menuItem = menuById.get(item.menuItemId);
    if (!menuItem) {
      throw new HttpError(
        400,
        `Menu item "${item.menuItemId}" is not available for this venue.`,
        { code: "menu_item_unavailable", menu_item_id: item.menuItemId },
      );
    }

    if (booleanValue(menuItem.is_available) === false) {
      throw new HttpError(
        409,
        `Menu item "${
          stringValue(menuItem.name) ?? item.menuItemId
        }" is sold out.`,
        { code: "menu_item_sold_out", menu_item_id: item.menuItemId },
      );
    }

    const price = numberValue(menuItem.price);
    if (price == undefined) {
      throw new HttpError(
        500,
        `Menu item "${item.menuItemId}" has an invalid price.`,
      );
    }

    return {
      menu_item_id: item.menuItemId,
      name: stringValue(menuItem.name) ?? "Menu Item",
      description: stringValue(menuItem.description) ?? "",
      image_url: stringValue(menuItem.image_url) ?? null,
      price: roundCurrency(price),
      quantity: item.quantity,
      note: item.note,
    };
  });

  const subtotal = roundCurrency(
    normalizedItems.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0,
    ),
  );
  const serviceFee = roundCurrency(subtotal * 0.05);
  const total = roundCurrency(subtotal + serviceFee);

  const orderData = await uniqueOrderInsert(supabase, {
    ...order,
    items: normalizedItems,
    subtotal,
    service_fee: serviceFee,
    total,
    venue_name: stringValue(venue.name) ??
      stringValue(order.venue_name) ??
      "Venue",
  });
  const orderId = stringValue(orderData.id);
  const receiptToken = orderId
    ? await issueOrderReceiptToken(orderId, venueId)
    : null;

  try {
    await dispatchVenueOperationalAlert(
      supabase,
      venueId,
      buildNewOrderPushNotification(orderData, stringValue(venue.country)),
    );
  } catch (error) {
    console.error("[orders-api] order push dispatch failed", error);
  }

  try {
    await dispatchVenueWhatsAppAlert(
      supabase,
      venueId,
      `New Order #${orderData.daily_sequence_number} received! Total: €${orderData.total}`,
    );
  } catch (error) {
    console.error("[orders-api] venue whatsapp alert dispatch failed", error);
  }

  return ok({
    ...orderData,
    venue_image_url: stringValue(venue.image_url) ?? null,
    ...(receiptToken == null ? {} : { receipt_token: receiptToken }),
  }, 201);
}

export async function handleGetOrdersForVenue(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .eq("venue_id", venueId)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[orders-api] get orders for venue failed", error);
    throw new HttpError(500, "Could not load venue orders.");
  }

  return ok(await attachPresentationDataToOrders(supabase, data ?? []));
}

export async function handleGetOrdersForUser(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const userId = requireString(body, "userId", "user_id");
  await requireSelfOrAdmin(supabase, req, userId);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[orders-api] get orders for user failed", error);
    throw new HttpError(500, "Could not load the user's orders.");
  }

  return ok(await attachPresentationDataToOrders(supabase, data ?? []));
}

export async function handleGetAllOrders(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[orders-api] get all orders failed", error);
    throw new HttpError(500, "Could not load orders.");
  }

  return ok(await attachPresentationDataToOrders(supabase, data ?? []));
}

export async function handleGetAdminDashboardKpis(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  await requireAdmin(supabase, req);

  const startOfDay = stringValue(body.startOfDay) ??
    new Date(new Date().setHours(0, 0, 0, 0)).toISOString();

  const [ordersResp] = await Promise.all([
    supabase.from("dinein_orders").select("total, created_at, status"),
  ]);

  const ordersData = ordersResp.data ?? [];
  let revenue_today = 0;
  let orders_today = 0;
  let total_revenue = 0;
  let cancelled_orders = 0;

  for (const o of ordersData) {
    const total = numberValue(o.total) ?? 0;
    const createdAt = stringValue(o.created_at);
    const status = stringValue(o.status);

    total_revenue += total;
    if (status == "cancelled") {
      cancelled_orders++;
    }

    if (createdAt && createdAt >= startOfDay) {
      orders_today++;
      revenue_today += total;
    }
  }

  return ok({
    orders_today,
    revenue_today: roundCurrency(revenue_today),
    total_orders: ordersData.length,
    total_revenue: roundCurrency(total_revenue),
    cancelled_orders,
  });
}

export async function handleGetOrderById(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const orderId = requireString(body, "orderId", "order_id");
  const receiptToken = stringValue(body.receiptToken) ??
    stringValue(body.receipt_token);

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("*")
    .eq("id", orderId)
    .maybeSingle();

  if (error) {
    console.error("[orders-api] get order by id failed", error);
    throw new HttpError(500, "Could not load the order.");
  }

  if (!data) {
    return ok(null);
  }

  if (receiptToken && await verifyOrderReceiptToken(receiptToken, orderId)) {
    return ok(
      (await attachPresentationDataToOrders(supabase, [data]))[0] ?? data,
    );
  }

  if (await adminUserId(supabase, req)) {
    return ok(
      (await attachPresentationDataToOrders(supabase, [data]))[0] ?? data,
    );
  }

  const order = asRecord(data);
  const user = await currentUser(req);
  if (user && stringValue(order.user_id) == user.id) {
    return ok(
      (await attachPresentationDataToOrders(supabase, [data]))[0] ?? data,
    );
  }

  const venueClaims = await venueSessionClaims(req);
  if (
    stringValue(venueClaims?.venue_id) != undefined &&
    stringValue(venueClaims?.venue_id) == stringValue(order.venue_id)
  ) {
    return ok(
      (await attachPresentationDataToOrders(supabase, [data]))[0] ?? data,
    );
  }

  throw new HttpError(403, "You are not allowed to access this order.");
}

export async function handleIssueOrderRealtimeAccess(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const orderId = stringValue(body.orderId) ?? stringValue(body.order_id);
  if (orderId) {
    const receiptToken = stringValue(body.receiptToken) ??
      stringValue(body.receipt_token);

    const { data, error } = await supabase
      .from("dinein_orders")
      .select("id, venue_id, user_id")
      .eq("id", orderId)
      .maybeSingle();

    if (error) {
      console.error(
        "[orders-api] issue order realtime access lookup failed",
        error,
      );
      throw new HttpError(500, "Could not load the order.");
    }

    if (!data) {
      throw new HttpError(404, "Order not found.");
    }

    const order = asRecord(data);
    const venueId = stringValue(order.venue_id);
    const userId = stringValue(order.user_id);
    const venueClaims = await venueSessionClaims(req);
    const current = await currentUser(req);
    const isAdmin = await adminUserId(supabase, req) != null;
    const hasGuestReceipt = receiptToken != null &&
      await verifyOrderReceiptToken(receiptToken, orderId);
    const hasVenueAccess = venueId != null &&
      stringValue(venueClaims?.venue_id) == venueId;
    const hasUserAccess = current != null && userId == current.id;

    if (!hasGuestReceipt && !hasVenueAccess && !hasUserAccess && !isAdmin) {
      throw new HttpError(403, "You are not allowed to access this order.");
    }

    return ok(
      await issueScopedRealtimeAccessToken({
        aud: "dinein-order-realtime",
        sub: orderId,
        order_id: orderId,
      }),
    );
  }

  const venueId = requireString(body, "venueId", "venue_id");
  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  return ok(
    await issueScopedRealtimeAccessToken({
      aud: "dinein-venue-realtime",
      sub: venueId,
      venue_id: venueId,
    }),
  );
}

export async function handleUpdateOrderStatus(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const orderId = requireString(body, "orderId", "order_id");
  const status = requireString(body, "status");

  if (!orderStatuses.has(status)) {
    throw new HttpError(400, `Unsupported order status: ${status}`, {
      code: "unsupported_order_status",
    });
  }

  const order = await orderStatusSnapshot(supabase, orderId);
  await authorizeVenueMutation(
    supabase,
    req,
    order.venueId,
    body.venue_session,
  );
  assertValidOrderStatusTransition(order.status, status);

  if (order.status == status) {
    return ok(true);
  }

  const { error } = await supabase
    .from("dinein_orders")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("id", orderId);

  if (error) {
    console.error("[orders-api] update order status failed", error);
    throw new HttpError(500, "Could not update the order status.");
  }

  return ok(true);
}

export async function handleMarkOrderPaid(
  supabase: ReturnType<typeof adminClient>,
  req: Request,
  body: JsonRecord,
): Promise<Response> {
  const orderId = requireString(body, "orderId", "order_id");

  const { data, error } = await supabase
    .from("dinein_orders")
    .select("venue_id,status,payment_status,payment_method")
    .eq("id", orderId)
    .maybeSingle();

  if (error) {
    console.error("[orders-api] order payment lookup failed", error);
    throw new HttpError(500, "Could not load the order.");
  }

  const order = asRecord(data);
  const venueId = stringValue(order.venue_id);
  const status = stringValue(order.status);
  const paymentMethod = stringValue(order.payment_method) ?? "cash";
  const paymentStatus = stringValue(order.payment_status) ??
    orderPaymentStatusForMethod(paymentMethod);

  if (!venueId || !status) {
    throw new HttpError(404, "Order not found.", { code: "order_not_found" });
  }

  await authorizeVenueMutation(supabase, req, venueId, body.venue_session);

  if (status == "cancelled") {
    throw new HttpError(409, "Cancelled orders cannot be marked as paid.", {
      code: "cancelled_order_unpayable",
    });
  }

  if (paymentStatus == "confirmed") {
    return ok(true);
  }

  const { error: updateError } = await supabase
    .from("dinein_orders")
    .update({
      payment_status: "confirmed",
      updated_at: new Date().toISOString(),
    })
    .eq("id", orderId);

  if (updateError) {
    console.error("[orders-api] mark order paid failed", updateError);
    throw new HttpError(500, "Could not confirm the order payment.");
  }

  return ok(true);
}
