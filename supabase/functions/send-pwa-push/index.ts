import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "npm:@supabase/server";
import webpush from "npm:web-push@3.6.7";

type NotificationRecord = {
  id?: string;
  user_id?: string | null;
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

function routeForNotification(record: NotificationRecord): string {
  // Keep notification targets relative to the PWA scope. This is required
  // when the Flutter Web app is deployed under a GitHub Pages sub-path.
  if (record.reference_type === "conversation" && record.reference_id) {
    return `./chat/${encodeURIComponent(record.reference_id)}`;
  }
  if (record.type === "chat") return "./chats";
  if (record.reference_type === "booking") return "./bookings";
  if (record.type === "booking") return "./bookings";
  return "./notifications";
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

    // The service worker owns icon/badge resolution so paths remain valid
    // for the deployed PWA scope rather than the site root.
    const notification = JSON.stringify({
      title: record.title || "استشارة",
      body: record.body || "لديك إشعار جديد",
      url: routeForNotification(record),
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

    return json({ sent, removed });
  }),
};
