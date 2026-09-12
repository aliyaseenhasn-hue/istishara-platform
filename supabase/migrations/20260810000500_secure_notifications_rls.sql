ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own
ON public.notifications
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

DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own
ON public.notifications
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

DROP POLICY IF EXISTS notifications_delete_own ON public.notifications;
CREATE POLICY notifications_delete_own
ON public.notifications
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

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
ON public.notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
ON public.notifications(user_id, is_read)
WHERE is_read = false;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;
