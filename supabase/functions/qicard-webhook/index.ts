import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
function b64(v: string) { const b = atob(v); return Uint8Array.from(b, c => c.charCodeAt(0)); }
async function verifySignature(payload: any, signature: string, pem: string) {
  const amount = payload.amount != null ? `${String(payload.amount)}.000` : "-";
  const data = [payload.paymentId || "-", amount, payload.currency || "-", payload.creationDate || "-", payload.status || "-"].join("|");
  const body = pem.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s/g, "");
  const key = await crypto.subtle.importKey("spki", b64(body), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  return crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64(signature), new TextEncoder().encode(data));
}
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  try {
    const publicKey = Deno.env.get("QICARD_WEBHOOK_PUBLIC_KEY");
    const signature = req.headers.get("X-Signature");
    const payload = await req.json();
    if (!publicKey) return new Response(JSON.stringify({ received: true, processed: false, reason: "webhook_public_key_not_configured" }), { status: 200, headers: { "Content-Type": "application/json" } });
    if (!signature) return new Response("Missing signature", { status: 401 });
    if (!(await verifySignature(payload, signature, publicKey))) return new Response("Invalid signature", { status: 401 });
    const url = Deno.env.get("SUPABASE_URL"), serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceRoleKey) throw new Error("Supabase service configuration is missing");
    const admin = createClient(url, serviceRoleKey), paymentId = payload?.paymentId;
    if (!paymentId) return new Response("Missing paymentId", { status: 400 });
    const { data: payment, error: pe } = await admin.from("payments").select("id,booking_id,amount,qicard_payment_id,status").eq("qicard_payment_id", paymentId).maybeSingle();
    if (pe) throw pe;
    if (!payment) return new Response(JSON.stringify({ received: true, processed: false, reason: "payment_not_found" }), { status: 200, headers: { "Content-Type": "application/json" } });
    const { data: booking, error: be } = await admin.from("bookings").select("id,price,status,lawyer_approved").eq("id", payment.booking_id).maybeSingle();
    if (be) throw be;
    if (!booking) return new Response(JSON.stringify({ received: true, processed: false, reason: "booking_not_found" }), { status: 200, headers: { "Content-Type": "application/json" } });
    if (Number(payload.amount) !== Number(booking.price) || payload.currency !== "IQD") return new Response("Payment amount/currency mismatch", { status: 409 });
    const raw = String(payload.status || "").toUpperCase();
    const success = raw === "SUCCESS", failed = raw === "FAILED" || raw === "AUTHENTICATION_FAILED";
    if (payment.status === "تم الدفع" && !success) {
      return new Response(JSON.stringify({ received: true, processed: false, reason: "terminal_success_not_reverted" }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    const mapped = success ? "تم الدفع" : failed ? "فشل الدفع" : "قيد معالجة الدفع", now = new Date().toISOString();
    const { error: ue } = await admin.from("payments").update({ status: mapped, qicard_raw_status: raw, qicard_payment_type: payload.paymentType ?? null, qicard_payment_system: payload.details?.paymentSystem ?? null, qicard_rrn: payload.details?.rrn ?? null, qicard_auth_id: payload.details?.authId ?? null, qicard_updated_at: now, verified_at: success ? now : null, verified_by: null }).eq("id", payment.id).eq("status", payment.status);
    if (ue) throw ue;
    let bookingStatus = booking.status;
    if (success) bookingStatus = booking.lawyer_approved ? "مؤكد" : "قيد مراجعة المحامي";
    else if (failed) bookingStatus = "قيد انتظار الدفع";
    else bookingStatus = "قيد معالجة الدفع";
    if (bookingStatus !== booking.status && !(booking.status === "مؤكد" && !success)) { const { error } = await admin.from("bookings").update({ status: bookingStatus }).eq("id", booking.id).eq("status", booking.status); if (error) throw error; }
    return new Response(JSON.stringify({ received: true, processed: true, payment_status: mapped, qicard_status: raw, booking_status: bookingStatus }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (e) { console.error("QiCard webhook error", e); return new Response("Webhook processing failed", { status: 500 }); }
});