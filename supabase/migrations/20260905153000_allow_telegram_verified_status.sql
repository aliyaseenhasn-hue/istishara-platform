-- Telegram authentication uses an intermediate verification state before
-- creating the Supabase session. Keep the database state machine aligned
-- with supabase/functions/telegram-auth-v2.
ALTER TABLE public.telegram_login_requests
  DROP CONSTRAINT IF EXISTS telegram_login_requests_status_check;

ALTER TABLE public.telegram_login_requests
  ADD CONSTRAINT telegram_login_requests_status_check
  CHECK (
    status = ANY (
      ARRAY[
        'waiting'::text,
        'code_sent'::text,
        'telegram_verified'::text,
        'verified'::text,
        'expired'::text,
        'failed'::text
      ]
    )
  );
