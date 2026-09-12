import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "npm:@supabase/server";
import webpush from "npm:web-push@3.6.7";

type NotificationRecord = {
  id?: string;
  user_id?: string | null;
  actor_profile_id?: string | null;
  title?: string | null;
  body?: string | null;
  type?: string | null;
  reference_id?: string | null;
  reference_type?: string | null;
};

type WebhookPayload = {
  type?: string;
  table?: string;
  schema?: string;
  record?: NotificationRecord | null;
};

const vapidPublicKey = Deno.env.get("PWA_VAPID_PUBLIC_KEY");
const vapidPrivateKey = Deno.env.get("PWA_VAPID_PRIVATE_KEY");
const vapidSubject = Deno.env.get("PWA_VAPID_SUBJECT") || "mailto:admin@astshara.app";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function routeForNotification(record: NotificationRecord, supabaseAdmin: any): Promise<string> {
  const refId = record.reference_id?.trim();
  const refType = record.reference_type?.trim();
  const type = record.type?.trim();

  if (refType === "conversation" && refId) return `./chat/${encodeURIComponent(refId)}`;
  if ((refType === "lawyer" || refType === "lawyer_profile") && refId) return `./lawyer-details/${encodeURIComponent(refId)}`;
  if (refType === "booking" && refId) return `./booking-details?booking_id=${encodeURIComponent(refId)}`;
  if (refType === "appointment_request" && refId) return `./appointment-requests?request_id=${encodeURIComponent(refId)}`;

  if (refType === "client_wallet_withdrawal") {
    if (type === "client_wallet_withdrawal_admin") {
      return refId
        ? `./admin/financial?withdrawal_id=${encodeURIComponent(refId)}`
        : "./admin/financial";
    }
    return refId
      ? `./client-wallet?withdrawal_id=${encodeURIComponent(refId)}`
      : "./client-wallet";
  }

  if (refType === "cancellation_request" && refId) {
    const requestResult = await supabaseAdmin
      .from("cancellation_requests")
      .select("booking_id")
      .eq("id", refId)
      .maybeSingle();

    let role: string | null = null;
    if (record.user_id) {
      const profileResult = await supabaseAdmin
        .from("profiles")
        .select("role")
        .eq("id", record.user_id)
        .maybeSingle();
      role = profileResult.data?.role?.toString() ?? null;
    }

    if (role === "admin" || role === "moderator") {
      return `./admin/cancellation-requests?request_id=${encodeURIComponent(refId)}`;
    }
    if (requestResult.data?.booking_id) {
      return `./booking-details?booking_id=${encodeURIComponent(requestResult.data.booking_id)}`;
    }
  }

  if (refType === "lawyer_penalty") return "./lawyer-wallet";
  if (type === "specialization_change_result") return "./lawyer-specialization-change";
  if (type === "payment") return refId && refType === "booking" ? `./booking-details?booking_id=${encodeURIComponent(refId)}` : "./bookings";
  if (type === "chat") return "./chats";
  if (type === "booking") return refId ? `./booking-details?booking_id=${encodeURIComponent(refId)}` : "./bookings";

  return record.id ? `./notifications?notification_id=${encodeURIComponent(record.id)}` : "./notifications";
}

export default {
  fetch: withSupabase({ auth: "secret" }, async (req, ctx) => {
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
    if (!vapidPublicKey || !vapidPrivateKey) {
      return json({ error: "PWA push is not configured: VAPID secrets are missing." }, 503);
    }

    let payload: WebhookPayload;
    try {
      payload = await req.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }

    if (
      payload.type !== "INSERT" ||
      payload.schema !== "public" ||
      payload.table !== "notifications" ||
      !payload.record ||
      !payload.record.user_id
    ) {
      return json({ error: "Invalid notifications INSERT webhook payload" }, 400);
    }

    const record = payload.record;
    const targetUserId = record.user_id;

    // Keep self-generated events inside the in-app notification center only.
    // The counterpart/admin/system still receives a background push normally.
    if (record.actor_profile_id && record.actor_profile_id === targetUserId) {
      return json({ sent: 0, removed: 0, skipped: "self_action" });
    }

    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

    const { data: subscriptions, error: subscriptionError } = await ctx.supabaseAdmin
      .from("pwa_push_subscriptions")
      .select("id, endpoint, p256dh, auth")
      .eq("user_id", targetUserId);

    if (subscriptionError) {
      console.error("send-pwa-push subscription lookup failed", subscriptionError.message);
      return json({ error: "Subscription lookup failed" }, 500);
    }

    if (!subscriptions?.length) return json({ sent: 0, removed: 0 });

    const url = await routeForNotification(record, ctx.supabaseAdmin);
    const notification = JSON.stringify({
      title: record.title || "استشارة",
      body: record.body || "لديك إشعار جديد",
      url,
      tag: `astshara-${record.type || "notification"}-${record.id || "new"}`,
      requireInteraction: false,
      notification_id: record.id || null,
      silent: false,
    });

    let sent = 0;
    let removed = 0;

    for (const subscription of subscriptions) {
      try {
        await webpush.sendNotification(
          {
            endpoint: subscription.endpoint,
            keys: { p256dh: subscription.p256dh, auth: subscription.auth },
          },
          notification,
        );
        sent++;
      } catch (error) {
        const statusCode = Number((error as { statusCode?: number })?.statusCode || 0);
        if (statusCode === 404 || statusCode === 410) {
          const { error: deleteError } = await ctx.supabaseAdmin
            .from("pwa_push_subscriptions")
            .delete()
            .eq("id", subscription.id);
          if (!deleteError) removed++;
        } else {
          console.error("send-pwa-push delivery failed", { statusCode });
        }
      }
    }

    return json({ sent, removed, url });
  }),
};
