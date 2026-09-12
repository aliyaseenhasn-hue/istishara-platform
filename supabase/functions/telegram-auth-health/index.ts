import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(() =>
  Response.json(
    { ok: false, error: "Diagnostic endpoint disabled in production." },
    { status: 410 },
  )
);
