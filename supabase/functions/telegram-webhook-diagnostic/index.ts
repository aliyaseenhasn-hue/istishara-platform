import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

Deno.serve(() =>
  new Response(
    JSON.stringify({ ok: false, error: 'Diagnostic endpoint disabled in production.' }),
    { status: 410, headers: { 'Content-Type': 'application/json; charset=utf-8' } },
  ),
);
