-- US-36 Turn a Voice Description into Text.
-- The transcribe-voice Edge Function writes an automatic Arabic transcript of the saved recording onto the draft case
-- (status pending, then done or failed) in the transcript columns from the Sprint 2 shared schema. The owner may correct
-- the text before sending the case; the database labels every correction "owner", so the label the veterinarian sees
-- can be trusted. Once the case is sent, the recording and the transcript (the confirmed one that the US-24 summary
-- uses) can no longer change.

-- The owner may change these columns of their own draft only (the cases_owner_update_draft policy from US-06);
-- the trigger below decides the source and status, whatever the app sends.
grant update (transcript, transcript_source, transcript_status) on public.cases to authenticated;

create function public.guard_case_transcript() returns trigger
language plpgsql set search_path = public as $$
begin
  if old.status <> 'draft' then
    if new.voice_path is distinct from old.voice_path then
      raise exception 'recording_locked';
    end if;
    if (new.transcript, new.transcript_source, new.transcript_status)
       is distinct from (old.transcript, old.transcript_source, old.transcript_status) then
      raise exception 'transcript_locked';
    end if;
    return new;
  end if;

  if new.voice_path is distinct from old.voice_path then
    -- A new or removed recording makes the old transcript meaningless; the app asks for a new one.
    new.transcript := null;
    new.transcript_source := null;
    new.transcript_status := null;
  elsif current_user = 'authenticated' then
    -- An edit from the app is the owner's correction. The app can never pick the label or the status itself.
    if new.transcript is distinct from old.transcript then
      new.transcript := nullif(btrim(new.transcript), '');
      new.transcript_source := case when new.transcript is not null then 'owner'::public.transcript_source end;
      new.transcript_status := case when new.transcript is not null then 'done'::public.transcript_status end;
    else
      new.transcript_source := old.transcript_source;
      new.transcript_status := old.transcript_status;
    end if;
  end if;

  -- Sent before a transcript was ready (or after it failed): the case goes with the recording only,
  -- and the veterinarian sees "Transcript unavailable".
  if new.status <> 'draft' and new.voice_path is not null and new.transcript_status is distinct from 'done' then
    new.transcript := null;
    new.transcript_source := null;
    new.transcript_status := 'failed';
  end if;
  return new;
end;
$$;

create trigger cases_transcript_guard
  before update on public.cases
  for each row execute function public.guard_case_transcript();

-- The recording of a sent case stays attached and unchanged: the owner can no longer overwrite or delete the file.
create function public.is_sent_case_voice(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.cases where voice_path = p_name and status <> 'draft')
$$;

create policy case_voice_keep_sent_update on storage.objects
  as restrictive for update to authenticated
  using (bucket_id <> 'case-voice' or not public.is_sent_case_voice(name));

create policy case_voice_keep_sent_delete on storage.objects
  as restrictive for delete to authenticated
  using (bucket_id <> 'case-voice' or not public.is_sent_case_voice(name));
