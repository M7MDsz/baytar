-- Sprint 3 shared schema (Mohammed).
-- Only the structure that more than one Sprint 3 story uses. Each story's behaviour (functions, policies) is in its
-- own migration, which depends on this file and on main only.
--   * The edited summary: US-26 writes it, US-39 counts it. 'edited' is a new summary state, and the edited_* columns
--     hold the veterinarian's version. `content` keeps exactly what the AI wrote, so an edited summary is still marked
--     as coming from the AI.
--   * consultation_ratings: US-38 writes it, the veterinarian's profile (US-10) and the dashboard (US-39) read it.
--     Nothing in the app reads or writes the table directly; US-38's functions do.

alter type public.summary_status add value if not exists 'edited' after 'generated';

alter table public.case_summaries
  add column edited_content jsonb,
  add column edited_by uuid references public.profiles (id),
  add column edited_at timestamptz,
  add constraint case_summaries_edit_recorded check (
    (edited_content is null and edited_by is null and edited_at is null)
    or (edited_content is not null and edited_by is not null and edited_at is not null)
  );

create table public.consultation_ratings (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null unique references public.appointments (id) on delete cascade,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  vet_id uuid not null references public.vet_profiles (id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  comment text check (comment is null or (btrim(comment) <> '' and char_length(comment) <= 300)),
  created_at timestamptz not null default now()
);

create index consultation_ratings_vet on public.consultation_ratings (vet_id);

alter table public.consultation_ratings enable row level security;
revoke all on public.consultation_ratings from anon, authenticated;
