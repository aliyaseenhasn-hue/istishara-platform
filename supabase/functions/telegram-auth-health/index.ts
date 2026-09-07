import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

Deno.serve(() => {
  const configured = Boolean(Deno.env.get('TELEGRAM_WEBHOOK_SECRET'));
  return Response.json({ ok: true, webhook_secret_configured: configured });
});
