-- US-25 Compare an AI Summary with the Original Description, US-27 Accept an AI Summary, US-28 Disregard an AI Summary.
-- The veterinarian's case view always returns the owner's original description (never replaced or hidden) next to the
-- AI summary and its status. Accept and Disregard are one decision of the assigned veterinarian, recorded with their id
-- and the time. A disregarded summary's content is no longer returned, so it can never be shown as accepted.
-- The reviewer columns and states are in the Sprint 2 shared schema. (The confirmation dialog before Accept or
-- Disregard is in the app.)

-- p_action is 'accept' or 'disregard'. Only a generated summary waiting for review can be decided, once.
create function public.review_summary(p_case uuid, p_action text) returns public.summary_status
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
    where case_id = p_case and status = 'generated'
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

-- Everything the case view compares, for the assigned veterinarian only:
--   description          the owner's original text, exactly as sent
--   voice_path           the recording (play it through a signed URL of the case-voice bucket)
--   transcript, transcript_label   shared schema: 'auto' (Automatic transcript), 'owner' (Corrected by owner),
--                                  'unavailable' (Transcript unavailable) or null without a recording
--   summary_status       null when no summary was requested; pending, generated, not_generated or failed
--                        ("could not be generated"), accepted or disregarded
--   summary_content      the AI summary (advisory, never a diagnosis), only while generated or accepted
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
  reviewed_at timestamptz
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
           case when s.status in ('generated', 'accepted') then s.content end,
           s.model, s.generated_at, p.full_name, s.reviewed_at
    from public.cases c
    left join public.case_summaries s on s.case_id = c.id
    left join public.profiles p on p.id = s.reviewed_by
    where c.id = p_case;
end;
$$;
