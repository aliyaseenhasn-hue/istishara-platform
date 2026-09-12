-- Provision the private chat room only after a real booking becomes active.
-- This keeps messaging unavailable before booking confirmation and prevents
-- clients from opening an empty chat with a lawyer they have not booked.

CREATE OR REPLACE FUNCTION public.ensure_conversation_for_confirmed_booking()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IN ('مؤكد', 'قيد التنفيذ', 'مكتمل')
     AND NEW.user_id IS NOT NULL
     AND NEW.lawyer_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.conversations c
      WHERE c.user_id = NEW.user_id
        AND c.lawyer_id = NEW.lawyer_id
    ) THEN
      INSERT INTO public.conversations(user_id, lawyer_id, last_message, last_message_at)
      VALUES (NEW.user_id, NEW.lawyer_id, NULL, NULL);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_conversation_for_confirmed_booking ON public.bookings;
CREATE TRIGGER trg_ensure_conversation_for_confirmed_booking
AFTER INSERT OR UPDATE OF status ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.ensure_conversation_for_confirmed_booking();

REVOKE ALL ON FUNCTION public.ensure_conversation_for_confirmed_booking() FROM PUBLIC, anon, authenticated;
