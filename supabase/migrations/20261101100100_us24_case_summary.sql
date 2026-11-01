-- US-24 Generate an AI-Structured Case Summary.
-- When a case is sent (draft -> submitted), a trigger asks the summarize-case Edge Function to organise the owner's
-- own description (the written text plus the transcript confirmed at submission) into chief complaint, duration,
-- onset, affected area and symptoms. The summary is advisory, never a diagnosis. It is stored in case_summaries from
-- the Sprint 2 shared schema, which only the assigned veterinarian and administrators can read.

-- Called only by summarize-case (service role). Idempotent: a summary that was already generated, found to have no
-- symptoms, or reviewed is never replaced; only a pending or failed one is (re)written. Returns the stored status.
create function public.store_case_summary(
  p_case uuid,
  p_status public.summary_status,
  p_content jsonb,
  p_source_text text,
  p_model text,
  p_failure_reason text default null
) returns public.summary_status
language plpgsql security definer set search_path = public as $$
declare
  v_status public.summary_status;
begin
  if p_status not in ('generated', 'not_generated', 'failed') then
    raise exception 'bad_status';
  end if;
  if not exists (select 1 from public.cases where id = p_case and status <> 'draft') then
    raise exception 'case_not_submitted';
  end if;
  insert into public.case_summaries as s
    (case_id, status, content, source_text, model, failure_reason, generated_at)
  values
    (p_case, p_status, case when p_status = 'generated' then p_content end, p_source_text, p_model,
     case when p_status <> 'generated' then p_failure_reason end, now())
  on conflict (case_id) do update
    set status = excluded.status,
        content = excluded.content,
        source_text = excluded.source_text,
        model = excluded.model,
        failure_reason = excluded.failure_reason,
        generated_at = excluded.generated_at
    where s.status in ('pending', 'failed')
  returning s.status into v_status;
  if v_status is null then
    select status into v_status from public.case_summaries where case_id = p_case;
  end if;
  return v_status;
end;
$$;

revoke execute on function public.store_case_summary(uuid, public.summary_status, jsonb, text, text, text)
  from public, anon, authenticated;
grant execute on function public.store_case_summary(uuid, public.summary_status, jsonb, text, text, text)
  to service_role;

-- AI: app_config holds ai_url (the summarize-case function URL) and ai_secret (same value as AI_WEBHOOK_SECRET).
-- Without both rows nothing is sent and no summary row is created.
create function public.request_case_summary() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_url text := (select value from public.app_config where key = 'ai_url');
  v_secret text := (select value from public.app_config where key = 'ai_secret');
begin
  if v_url is not null and v_secret is not null then
    insert into public.case_summaries (case_id) values (new.id) on conflict (case_id) do nothing;
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object('case_id', new.id),
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_secret),
      timeout_milliseconds := 60000
    );
  end if;
  return null;
end;
$$;

create trigger cases_request_summary
  after update of status on public.cases
  for each row when (old.status = 'draft' and new.status = 'submitted')
  execute function public.request_case_summary();
