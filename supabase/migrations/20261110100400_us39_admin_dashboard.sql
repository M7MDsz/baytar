-- US-39 View the Administration Dashboard.
-- Key figures for one period [p_from, p_to), for administrators only. Totals only: no names, contact details or case
-- descriptions. A period with no activity returns zeros. Each figure counts the matching records:
--   new_owner_accounts        owner profiles created in the period
--   verified_vets             veterinarians an administrator verified in the period (US-32 decisions)
--   submitted_cases           cases sent in the period (US-07)
--   completed_consultations   appointments completed, by the time the consultation ended (US-19)
--   cancelled_appointments    appointments cancelled in the period (US-13)
--   average_rating, rating_count   ratings given in the period (US-38); the average is 0 when there are none
--   pending_verifications     veterinarians waiting for verification now, whatever the period
--   summaries_*               AI summaries of cases sent in the period, each in exactly one group:
--                             accepted (as the AI wrote it), edited (by the veterinarian, then accepted or still
--                             waiting), disregarded, not_generated (no symptom found, or the AI call failed), and
--                             awaiting (still being made, or waiting for the veterinarian)

create function public.admin_dashboard(p_from timestamptz, p_to timestamptz)
returns table (
  new_owner_accounts int,
  verified_vets int,
  submitted_cases int,
  completed_consultations int,
  cancelled_appointments int,
  average_rating numeric,
  rating_count int,
  pending_verifications int,
  summaries_accepted int,
  summaries_edited int,
  summaries_disregarded int,
  summaries_not_generated int,
  summaries_awaiting int
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden';
  end if;
  if p_from is null or p_to is null or p_from >= p_to then
    raise exception 'bad_period';
  end if;
  return query
    with s as (
      select cs.status, cs.edited_at
      from public.case_summaries cs
      join public.cases c on c.id = cs.case_id
      where c.submitted_at >= p_from and c.submitted_at < p_to
    )
    select
      (select count(*)::int from public.profiles
        where role = 'owner' and created_at >= p_from and created_at < p_to),
      (select count(distinct vet_id)::int from public.vet_decisions
        where decision = 'verified' and decided_at >= p_from and decided_at < p_to),
      (select count(*)::int from public.cases where submitted_at >= p_from and submitted_at < p_to),
      (select count(*)::int from public.appointments
        where status = 'completed' and coalesce(ended_at, starts_at) >= p_from and coalesce(ended_at, starts_at) < p_to),
      (select count(*)::int from public.appointments
        where status = 'cancelled' and cancelled_at >= p_from and cancelled_at < p_to),
      (select coalesce(round(avg(stars), 2), 0) from public.consultation_ratings
        where created_at >= p_from and created_at < p_to),
      (select count(*)::int from public.consultation_ratings where created_at >= p_from and created_at < p_to),
      (select count(*)::int from public.vet_profiles where status = 'pending'),
      (select count(*)::int from s where status = 'accepted' and edited_at is null),
      (select count(*)::int from s where edited_at is not null and status <> 'disregarded'),
      (select count(*)::int from s where status = 'disregarded'),
      (select count(*)::int from s where status in ('not_generated', 'failed')),
      (select count(*)::int from s where status in ('pending', 'generated'));
end;
$$;
