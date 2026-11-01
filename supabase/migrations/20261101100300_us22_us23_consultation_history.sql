-- US-22 View an Animal's Consultation History, US-23 Open a Past Consultation Record.
-- For the owner only, and read-only. A consultation is an appointment for one of the animal's cases that took place
-- (started or completed); cancelled bookings and ones that have not started yet are not history.
-- Outcome details follow the US-16 rule: an owner sees an outcome only after the veterinarian approves it.

-- The animal's consultations, newest first. outcome_status is 'approved' once the outcome can be read, else 'pending'.
-- An animal without consultations returns no rows (the empty state); another owner's animal is refused.
create function public.animal_history(p_animal uuid)
returns table (
  appointment_id uuid,
  case_id uuid,
  case_number text,
  consultation_date date,
  starts_at timestamptz,
  vet_name text,
  outcome_status text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.animals where id = p_animal and owner_id = auth.uid()) then
    raise exception 'animal_not_found';
  end if;
  return query
    select a.id, c.id, c.case_number, (a.starts_at at time zone 'Asia/Riyadh')::date, a.starts_at, p.full_name,
           case when exists (
             select 1 from public.consultation_outcomes o where o.appointment_id = a.id and o.status = 'approved'
           ) then 'approved' else 'pending' end
    from public.appointments a
    join public.cases c on c.id = a.case_id
    join public.profiles p on p.id = a.vet_id
    where c.animal_id = p_animal
      and a.owner_id = auth.uid()
      and (a.status = 'completed' or (a.status = 'booked' and a.started_at is not null))
    order by a.starts_at desc;
end;
$$;

-- One past consultation: the linked case description, the date and veterinarian, the documented outcome (only once
-- approved, through owner_outcomes from US-16) and the veterinarian's referral, if any.
create function public.consultation_record(p_appointment uuid)
returns table (
  appointment_id uuid,
  case_id uuid,
  case_number text,
  animal_id uuid,
  animal_name text,
  consultation_date date,
  starts_at timestamptz,
  vet_name text,
  description text,
  has_voice boolean,
  outcome_status text,
  findings text,
  guidance text,
  owner_notes text,
  approved_at timestamptz,
  referral_reason text,
  referral_instructions text,
  referred_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.appointments a
    where a.id = p_appointment
      and a.owner_id = auth.uid()
      and (a.status = 'completed' or (a.status = 'booked' and a.started_at is not null))
  ) then
    raise exception 'record_not_found';
  end if;
  return query
    select a.id, c.id, c.case_number, an.id, an.name,
           (a.starts_at at time zone 'Asia/Riyadh')::date, a.starts_at, p.full_name,
           c.description, c.voice_path is not null,
           case when o.appointment_id is null then 'pending' else 'approved' end,
           o.findings, o.guidance, o.owner_notes, o.approved_at,
           r.reason, r.instructions, r.created_at
    from public.appointments a
    join public.cases c on c.id = a.case_id
    join public.animals an on an.id = c.animal_id
    join public.profiles p on p.id = a.vet_id
    left join lateral public.owner_outcomes(null, a.id) o on true
    left join lateral (
      select rf.reason, rf.instructions, rf.created_at
      from public.referrals rf
      where rf.case_id = a.case_id and rf.vet_id = a.vet_id
      order by rf.created_at desc
      limit 1
    ) r on true
    where a.id = p_appointment;
end;
$$;
