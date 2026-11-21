-- US-26 Edit an AI-Structured Summary.
-- The assigned veterinarian can correct a generated summary before deciding on it. The AI's own content is kept as it
-- was, so the summary stays marked as coming from the AI; the veterinarian's version goes into edited_content with who
-- edited it and when (Sprint 3 shared schema), and that latest version is what the case view shows. The owner's
-- original description is never touched. An edited summary can still be accepted (US-27) or disregarded (US-28).

-- One summary item: {"value": text of 1 to 300 characters, "quote": optional text}.
create function public.valid_summary_item(p jsonb) returns boolean
language sql immutable as $$
  select coalesce(
    jsonb_typeof(p) = 'object'
    and jsonb_typeof(p -> 'value') = 'string'
    and btrim(p ->> 'value') <> ''
    and char_length(p ->> 'value') <= 300
    and (p -> 'quote' is null or jsonb_typeof(p -> 'quote') in ('string', 'null')),
    false)
$$;

-- The same shape as the AI's summary: only its five keys, each field an item or null, symptoms a list of at most 15
-- items, and at least one item in total.
create function public.valid_summary_content(p jsonb) returns boolean
language plpgsql immutable as $$
declare
  k text;
  item jsonb;
  n int := 0;
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    return false;
  end if;
  for k in select jsonb_object_keys(p) loop
    if k not in ('chief_complaint', 'duration', 'onset', 'affected_area', 'symptoms') then
      return false;
    end if;
  end loop;
  foreach k in array array['chief_complaint', 'duration', 'onset', 'affected_area'] loop
    item := p -> k;
    continue when item is null or jsonb_typeof(item) = 'null';
    if not public.valid_summary_item(item) then
      return false;
    end if;
    n := n + 1;
  end loop;
  if p -> 'symptoms' is not null and jsonb_typeof(p -> 'symptoms') <> 'null' then
    if jsonb_typeof(p -> 'symptoms') <> 'array' or jsonb_array_length(p -> 'symptoms') > 15 then
      return false;
    end if;
    for item in select value from jsonb_array_elements(p -> 'symptoms') loop
      if not public.valid_summary_item(item) then
        return false;
      end if;
      n := n + 1;
    end loop;
  end if;
  return n > 0;
end;
$$;

-- Every quote in a summary: the owner's own words each item came from.
create function public.summary_quotes(p jsonb) returns text[]
language sql immutable as $$
  select coalesce(array_agg(q), '{}')
  from (
    select p -> k ->> 'quote' as q
    from unnest(array['chief_complaint', 'duration', 'onset', 'affected_area']) as k
    union all
    select s ->> 'quote'
    from jsonb_array_elements(case when jsonb_typeof(p -> 'symptoms') = 'array' then p -> 'symptoms' else '[]' end) as s
  ) x
  where q is not null
$$;

-- The assigned veterinarian saves their version of a generated (or already edited) summary. A quote can only be one the
-- AI's summary already carried, so the owner's words shown under an item are always really theirs; an item the
-- veterinarian adds has no quote. Returns 'edited'.
create function public.edit_summary(p_case uuid, p_content jsonb) returns public.summary_status
language plpgsql security definer set search_path = public as $$
declare
  s public.case_summaries;
begin
  if not public.is_assigned_vet(p_case) then
    raise exception 'not_assigned';
  end if;
  if not public.valid_summary_content(p_content) then
    raise exception 'bad_summary';
  end if;
  select * into s from public.case_summaries where case_id = p_case for update;
  if not found or s.status not in ('generated', 'edited') then
    if s.status in ('accepted', 'disregarded') then
      raise exception 'already_reviewed';
    end if;
    raise exception 'no_summary_to_edit';
  end if;
  if exists (
    select 1 from unnest(public.summary_quotes(p_content)) as q
    where not (q = any (public.summary_quotes(s.content)))
  ) then
    raise exception 'quote_not_from_owner';
  end if;
  update public.case_summaries
    set status = 'edited', edited_content = p_content, edited_by = auth.uid(), edited_at = now()
    where case_id = p_case;
  return 'edited'::public.summary_status;
end;
$$;

-- US-27/US-28: an edited summary can be accepted or disregarded too (it was only 'generated' before).
create or replace function public.review_summary(p_case uuid, p_action text) returns public.summary_status
language plpgsql security definer set search_path = public as $$
declare
  v_status public.summary_status;
begin
  if not public.is_assigned_vet(p_case) then
    raise exception 'not_assigned';
  end if;
  if p_action is null or p_action not in ('accept', 'disregard') then
    raise exception 'bad_action';
  end if;
  update public.case_summaries
    set status = case when p_action = 'accept' then 'accepted' else 'disregarded' end::public.summary_status,
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where case_id = p_case and status in ('generated', 'edited')
    returning status into v_status;
  if v_status is null then
    select status into v_status from public.case_summaries where case_id = p_case;
    if v_status in ('accepted', 'disregarded') then
      raise exception 'already_reviewed';
    end if;
    raise exception 'no_summary_to_review';
  end if;
  return v_status;
end;
$$;

-- US-25's case view, now with the edit: summary_content is the latest saved version (the veterinarian's when edited),
-- ai_content is what the AI wrote, and edited_by_name/edited_at say who edited it and when. A disregarded summary still
-- returns no content at all.
drop function public.vet_case_summary(uuid);
create function public.vet_case_summary(p_case uuid)
returns table (
  case_id uuid,
  case_number text,
  description text,
  voice_path text,
  transcript text,
  transcript_label text,
  summary_status public.summary_status,
  summary_content jsonb,
  summary_model text,
  summary_generated_at timestamptz,
  reviewed_by_name text,
  reviewed_at timestamptz,
  ai_content jsonb,
  edited_by_name text,
  edited_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_assigned_vet(p_case) then
    raise exception 'not_assigned';
  end if;
  return query
    select c.id, c.case_number, c.description, c.voice_path,
           case when public.transcript_label(c) in ('auto', 'owner') then c.transcript end,
           public.transcript_label(c),
           s.status,
           case when s.status in ('generated', 'edited', 'accepted') then coalesce(s.edited_content, s.content) end,
           s.model, s.generated_at, p.full_name, s.reviewed_at,
           case when s.status in ('generated', 'edited', 'accepted') then s.content end,
           e.full_name, s.edited_at
    from public.cases c
    left join public.case_summaries s on s.case_id = c.id
    left join public.profiles p on p.id = s.reviewed_by
    left join public.profiles e on e.id = s.edited_by
    where c.id = p_case;
end;
$$;
