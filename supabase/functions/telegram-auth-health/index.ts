import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
Deno.serve(() => Response.json({ ok: true, webhook_secret_configured: Boolean(Deno.env.get('TELEGRAM_WEBHOOK_SECRET')) }));
