-- Sprint 2 shared schema (Mohammed).
-- Only the structure that more than one Sprint 2 story uses. Each story's own migration depends on this file and on
-- main only, so the parts can be applied and merged in any order. Story behaviour (triggers, the Edge Function hook,
-- RPCs) is in each story's own migration.
--   * The transcript columns on cases: US-36 writes them, US-24 reads them, US-25 shows them to the veterinarian.
--     transcript_label is here too, because the owner's screen (US-36) and the veterinarian's view (US-25) must show
--     the same label.
--   * case_summaries: US-24 writes it, US-25/27/28 review it. Its status type has every state, and its base row
--     security lets only the assigned veterinarian and administrators read it; nothing in the app can write it.

create type public.transcript_source as enum ('auto', 'owner');
create type public.transcript_status as enum ('pending', 'done', 'failed');

alter table public.cases
  add column transcript text,
  add column transcript_source public.transcript_source,
  add column transcript_status public.transcript_status,
  add constraint cases_transcript_not_blank check (transcript is null or btrim(transcript) <> ''),
  add constraint cases_transcript_needs_voice check (transcript is null or voice_path is not null);

-- The label shown above the transcript: 'auto' (Automatic transcript), 'owner' (Corrected by owner),
-- 'unavailable' (Transcript unavailable), 'pending' while a draft is being transcribed, or null without a recording.
-- The app can read it as a computed column: select('*, transcript_label').
create function public.transcript_label(p_case public.cases) returns text
language sql stable as $$
  select case
    when p_case.voice_path is null then null
    when p_case.transcript_status = 'done' and p_case.transcript is not null then p_case.transcript_source::text
    when p_case.transcript_status = 'pending' then 'pending'
    else 'unavailable'
  end
$$;

-- Every state an AI case summary can be in:
--   pending        summarize-case has been asked and has not answered yet (US-24)
--   generated      a summary exists and is waiting for the veterinarian's review (US-24, US-25)
--   not_generated  the description mentions no symptom, so no summary was made ("could not be generated") (US-24)
--   failed         the AI call failed or its answer could not be used ("could not be generated") (US-24)
--   accepted       the veterinarian accepted it (US-27)
--   disregarded    the veterinarian disregarded it (US-28)
-- Sprint 3's US-26 adds 'edited' with `alter type public.summary_status add value 'edited'` and its own edited_*
-- columns; `content` always keeps exactly what the AI wrote, so an edited summary is still marked AI-originated.
create type public.summary_status as enum ('pending', 'generated', 'not_generated', 'failed', 'accepted', 'disregarded');

create table public.case_summaries (
  case_id uuid primary key references public.cases (id) on delete cascade,
  status public.summary_status not null default 'pending',
  content jsonb,
  source_text text,
  model text,
  failure_reason text,
  generated_at timestamptz,
  created_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  constraint case_summaries_content_present
    check (content is not null or status in ('pending', 'not_generated', 'failed')),
  constraint case_summaries_review_recorded
    check (status not in ('accepted', 'disregarded') or (reviewed_by is not null and reviewed_at is not null))
);

alter table public.case_summaries enable row level security;

create policy case_summaries_vet_select on public.case_summaries
  for select to authenticated using (public.is_assigned_vet(case_id));

create policy case_summaries_admin_select on public.case_summaries
  for select to authenticated using (public.is_admin());

revoke insert, update, delete on public.case_summaries from anon, authenticated;
