-- The old 8-argument create_booking overload bypassed the current WhatsApp-aware flow.
-- Keep only the 9-argument function used by the application.
drop function if exists public.create_booking(uuid,timestamptz,text,text,text,text,text,uuid);
