import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

Deno.serve((req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { status: 200, headers });
  }

  return new Response(
    JSON.stringify({
      ok: false,
      error: 'تم إيقاف مسار Telegram القديم. استخدم telegram-auth-v2.',
    }),
    { status: 410, headers },
  );
});
