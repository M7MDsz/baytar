-- US-19 Conduct a Virtual Consultation (veterinarian side).
-- Extends join_consultation from US-14 with the veterinarian's window (15 minutes before to 15 after),
-- records start and end times, and gives the assigned veterinarian a case panel during the call.

create or replace function public.join_consultation(p_appointment uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
  is_owner boolean;
  before_start interval;
  joined timestamptz;
begin
  select * into a from public.appointments where id = p_appointment for update;
  if not found then
    return 'not_found';
  end if;
  if a.owner_id = auth.uid() then
    is_owner := true;
    before_start := interval '10 minutes';
    joined := a.owner_joined_at;
  elsif a.vet_id = auth.uid() then
    is_owner := false;
    before_start := interval '15 minutes';
    joined := a.vet_joined_at;
  else
    return 'forbidden';
  end if;
  if a.status = 'cancelled' then
    return 'cancelled';
  end if;
  if not (joined is not null and a.ended_at is null and now() < a.starts_at + interval '30 minutes') then
    if now() < a.starts_at - before_start then
      return 'too_early';
    end if;
    if now() > a.starts_at + interval '15 minutes' or a.ended_at is not null then
      return 'too_late';
    end if;
  end if;
  if is_owner then
    update public.appointments set owner_joined_at = coalesce(owner_joined_at, now()) where id = a.id;
  else
    update public.appointments
      set vet_joined_at = coalesce(vet_joined_at, now()), started_at = coalesce(started_at, now())
      where id = a.id;
  end if;
  return 'ok';
end;
$$;

create function public.end_consultation(p_appointment uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.appointments
    set ended_at = coalesce(ended_at, now()), status = 'completed'
    where id = p_appointment and vet_id = auth.uid() and status = 'booked' and started_at is not null;
  if not found then
    raise exception 'not_in_progress';
  end if;
end;
$$;

create function public.consultation_case_panel(p_appointment uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'case_number', c.case_number,
    'description', c.description,
    'has_voice', c.voice_path is not null,
    'animal', jsonb_build_object(
      'name', an.name, 'species', an.species, 'breed', an.breed, 'sex', an.sex,
      'birth_date', an.birth_date, 'age_years', an.age_years, 'weight_kg', an.weight_kg,
      'conditions', an.conditions, 'allergies', an.allergies
    )
  )
  from public.appointments a
  join public.cases c on c.id = a.case_id
  join public.animals an on an.id = c.animal_id
  where a.id = p_appointment and a.vet_id = auth.uid()
$$;
