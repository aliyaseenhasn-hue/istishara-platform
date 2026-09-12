import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });

async function removeFolder(admin: ReturnType<typeof createClient>, bucket: string, prefix: string) {
  const normalized = prefix.replace(/^\/+|\/+$/g, "");
  if (!normalized) return;
  let offset = 0;
  const pageSize = 100;
  while (true) {
    const { data, error } = await admin.storage.from(bucket).list(normalized, {
      limit: pageSize,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw error;
    if (!data || data.length === 0) break;
    const files = data.filter((item) => item.id != null).map((item) => `${normalized}/${item.name}`);
    if (files.length > 0) {
      const { error: removeError } = await admin.storage.from(bucket).remove(files);
      if (removeError) throw removeError;
    }
    if (data.length < pageSize) break;
    if (files.length === 0) offset += pageSize;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "يجب تسجيل الدخول أولاً" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "إعدادات الخادم غير مكتملة" }, 500);
    }

    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch (_) {}
    if (body.confirm !== true) return json({ error: "تأكيد حذف الحساب مطلوب" }, 400);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "جلسة الدخول غير صالحة" }, 401);
    const user = userData.user;

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id")
      .eq("auth_id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;

    const { error: closeError } = await userClient.rpc("close_my_account");
    if (closeError) return json({ error: closeError.message }, 409);

    const prefixes = [user.id];
    if (profile?.id && profile.id !== user.id) prefixes.push(profile.id);
    const buckets = ["avatars", "lawyer_documents", "lawyer_achievements", "receipts"];
    const cleanupWarnings: string[] = [];
    for (const bucket of buckets) {
      for (const prefix of prefixes) {
        try {
          await removeFolder(admin, bucket, prefix);
        } catch (error) {
          cleanupWarnings.push(`${bucket}/${prefix}: ${error instanceof Error ? error.message : String(error)}`);
        }
      }
    }

    if (user.phone) {
      const { error } = await admin.from("telegram_login_requests").delete().eq("phone", user.phone);
      if (error) cleanupWarnings.push(`telegram_login_requests: ${error.message}`);
    }

    const { error: deleteAuthError } = await admin.auth.admin.deleteUser(user.id, false);
    if (deleteAuthError) {
      console.error("auth delete failed", deleteAuthError);
      return json({
        error: "تم إخفاء بيانات الحساب، لكن تعذر إكمال حذف هوية تسجيل الدخول. يرجى التواصل مع الدعم لإكمال الطلب.",
        cleanup_warnings: cleanupWarnings,
      }, 500);
    }

    return json({ ok: true, cleanup_warnings: cleanupWarnings });
  } catch (error) {
    console.error("delete-account error", error);
    return json({ error: error instanceof Error ? error.message : "تعذر حذف الحساب" }, 500);
  }
});
