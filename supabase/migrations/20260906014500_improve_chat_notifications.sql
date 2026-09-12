-- Give incoming chat notifications a direct conversation reference so the
-- notification can open the exact Messenger-style chat thread.

CREATE OR REPLACE FUNCTION public.notify_message_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_lawyer_id uuid;
  v_recipient uuid;
BEGIN
  SELECT user_id, lawyer_id
    INTO v_user_id, v_lawyer_id
  FROM public.conversations
  WHERE id = NEW.conversation_id;

  v_recipient := CASE
    WHEN NEW.sender_id = v_user_id THEN v_lawyer_id
    ELSE v_user_id
  END;

  IF v_recipient IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.notifications
    WHERE user_id = v_recipient
      AND type = 'chat'
      AND reference_id = NEW.conversation_id::text
      AND reference_type = 'conversation'
      AND created_at > now() - interval '5 seconds'
  ) THEN
    INSERT INTO public.notifications(
      user_id,
      title,
      body,
      type,
      is_read,
      reference_id,
      reference_type
    )
    VALUES (
      v_recipient,
      'رسالة جديدة',
      'لديك رسالة جديدة في المحادثة.',
      'chat',
      false,
      NEW.conversation_id::text,
      'conversation'
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_message_event ON public.messages;
CREATE TRIGGER trg_notify_message_event
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.notify_message_event();

REVOKE ALL ON FUNCTION public.notify_message_event() FROM PUBLIC, anon, authenticated;
