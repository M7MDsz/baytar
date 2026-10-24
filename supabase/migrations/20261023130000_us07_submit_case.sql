-- US-07 Submit a Case.
-- A draft becomes submitted only here: it needs a written or a voice description, and it gets a unique case number.

create function public.submit_case(p_case uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  c public.cases;
  v_number text;
begin
  select * into c from public.cases where id = p_case for update;
  if not found or c.owner_id <> auth.uid() then
    raise exception 'case_not_found';
  end if;
  if c.status <> 'draft' then
    raise exception 'already_submitted';
  end if;
  if btrim(coalesce(c.description, '')) = '' and c.voice_path is null then
    raise exception 'missing_description';
  end if;
  v_number := 'BYT-' || to_char(now() at time zone 'Asia/Riyadh', 'YY') || '-'
              || lpad(nextval('public.case_number_seq')::text, 5, '0');
  update public.cases
    set status = 'submitted', submitted_at = now(), case_number = v_number
    where id = p_case;
  return v_number;
end;
$$;
