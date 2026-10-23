-- US-16 View the Consultation Outcome.
-- Owners see an outcome only after the veterinarian approves it, and they can never edit it
-- (there is no owner insert/update policy on consultation_outcomes).

create function public.owner_outcomes(p_animal uuid default null, p_appointment uuid default null)
returns table (
  appointment_id uuid,
  case_id uuid,
  case_number text,
  animal_id uuid,
  animal_name text,
  vet_name text,
  consultation_date date,
  findings text,
  guidance text,
  owner_notes text,
  approved_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select o.appointment_id, o.case_id, c.case_number, o.animal_id, an.name, p.full_name,
         o.consultation_date, o.findings, o.guidance, o.owner_notes, o.approved_at
  from public.consultation_outcomes o
  join public.cases c on c.id = o.case_id
  join public.animals an on an.id = o.animal_id
  join public.profiles p on p.id = o.vet_id
  where c.owner_id = auth.uid()
    and o.status = 'approved'
    and (p_animal is null or o.animal_id = p_animal)
    and (p_appointment is null or o.appointment_id = p_appointment)
  order by o.consultation_date desc
$$;

create policy referrals_owner_select on public.referrals
  for select to authenticated
  using (exists (select 1 from public.cases c where c.id = case_id and c.owner_id = auth.uid()));
