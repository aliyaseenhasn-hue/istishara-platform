CREATE TABLE IF NOT EXISTS public.push_device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  platform text NOT NULL CHECK (platform IN ('android', 'iOS', 'macOS', 'windows', 'linux')),
  is_active boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS push_device_tokens_user_active_idx
  ON public.push_device_tokens(user_id, is_active);

ALTER TABLE public.push_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS push_device_tokens_select_own ON public.push_device_tokens;
CREATE POLICY push_device_tokens_select_own
  ON public.push_device_tokens
  FOR SELECT
  TO authenticated
  USING (
    user_id = (
      SELECT p.id
      FROM public.profiles p
      WHERE p.auth_id = auth.uid()
      LIMIT 1
    )
  );

DROP POLICY IF EXISTS push_device_tokens_insert_own ON public.push_device_tokens;
CREATE POLICY push_device_tokens_insert_own
  ON public.push_device_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (
      SELECT p.id
      FROM public.profiles p
      WHERE p.auth_id = auth.uid()
      LIMIT 1
    )
  );

DROP POLICY IF EXISTS push_device_tokens_update_own ON public.push_device_tokens;
CREATE POLICY push_device_tokens_update_own
  ON public.push_device_tokens
  FOR UPDATE
  TO authenticated
  USING (
    user_id = (
      SELECT p.id
      FROM public.profiles p
      WHERE p.auth_id = auth.uid()
      LIMIT 1
    )
  )
  WITH CHECK (
    user_id = (
      SELECT p.id
      FROM public.profiles p
      WHERE p.auth_id = auth.uid()
      LIMIT 1
    )
  );

DROP POLICY IF EXISTS push_device_tokens_delete_own ON public.push_device_tokens;
CREATE POLICY push_device_tokens_delete_own
  ON public.push_device_tokens
  FOR DELETE
  TO authenticated
  USING (
    user_id = (
      SELECT p.id
      FROM public.profiles p
      WHERE p.auth_id = auth.uid()
      LIMIT 1
    )
  );

CREATE OR REPLACE FUNCTION public.set_push_device_tokens_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_device_tokens_updated_at ON public.push_device_tokens;
CREATE TRIGGER trg_push_device_tokens_updated_at
BEFORE UPDATE ON public.push_device_tokens
FOR EACH ROW
EXECUTE FUNCTION public.set_push_device_tokens_updated_at();

COMMENT ON TABLE public.push_device_tokens IS
  'Native FCM device registrations used by the trusted server-side push dispatcher. Web/PWA push remains on its existing channel.';
