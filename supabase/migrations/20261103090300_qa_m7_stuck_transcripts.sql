-- QA M-7: transcribe-voice marks the draft "pending" before it calls Gemini. If the function is killed meanwhile
-- (platform limit, deploy, crash) nothing ever wrote "done" or "failed", so the draft stayed "pending" for good.
-- Now the database records when a transcript became pending, a job turns one that is still pending after
-- 3 minutes into "failed" (the function finishes within about a minute, so it can only be dead by then), and the
-- app reads the same rule as a computed column, so the owner sees "try again" without waiting for the job.

alter table public.cases add column transcript_pending_since timestamptz;

create function public.stamp_transcript_pending() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.transcript_status = 'pending' then
    if tg_op = 'INSERT' or old.transcript_status is distinct from 'pending' or new.transcript_pending_since is null then
      new.transcript_pending_since := now();
    end if;
  else
    new.transcript_pending_since := null;
  end if;
  return new;
end;
$$;

-- Runs after cases_transcript_guard (triggers fire in name order), so it sees the final status.
create trigger cases_transcript_pending_stamp
  before insert or update on public.cases
  for each row execute function public.stamp_transcript_pending();

-- The one definition of "stuck". The app can read it as a computed column: select('…, transcript_pending_expired').
create function public.transcript_pending_expired(p_case public.cases) returns boolean
language sql stable set search_path = public as $$
  select p_case.transcript_status = 'pending'
     and p_case.transcript_pending_since < now() - interval '3 minutes'
$$;

create function public.expire_stuck_transcripts() returns void
language sql security definer set search_path = public as $$
  update public.cases c
     set transcript = null, transcript_source = null, transcript_status = 'failed'
   where c.status = 'draft' and public.transcript_pending_expired(c);
$$;

revoke execute on function public.expire_stuck_transcripts() from public, anon, authenticated;

select cron.schedule('expire-stuck-transcripts', '* * * * *', 'select public.expire_stuck_transcripts()');

-- A draft already pending when this runs gets a start time now, so the job resolves it within a few minutes.
update public.cases set transcript_pending_since = now()
 where transcript_status = 'pending' and transcript_pending_since is null;
