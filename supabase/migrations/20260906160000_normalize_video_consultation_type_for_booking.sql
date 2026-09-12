-- Keep the booking RPC compatible with the existing Flutter UI label "مرئية".
-- The canonical stored value remains "فيديو", matching the existing booking rules.

do $$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid)
    into v_def
  from pg_proc p
  where p.oid = to_regprocedure('public.create_booking(uuid,timestamptz,text,text,text,text,text,uuid,text)');

  if v_def is null then
    raise exception 'create_booking function not found';
  end if;

  v_def := replace(
    v_def,
    'v_consultation_type text := trim(coalesce(p_consultation_type,''''));',
    'v_consultation_type text := case when trim(coalesce(p_consultation_type,'''')) = ''مرئية'' then ''فيديو'' else trim(coalesce(p_consultation_type,'''')) end;'
  );

  if v_def = pg_get_functiondef(to_regprocedure('public.create_booking(uuid,timestamptz,text,text,text,text,text,uuid,text)')) then
    raise exception 'create_booking definition pattern not found; no change applied';
  end if;

  execute v_def;
end $$;
