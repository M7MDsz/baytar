-- US-11 Book an Appointment.
-- The slot row is locked while booking and a unique index allows one live booking per slot,
-- so two owners can never get the same time.

create function public.available_slots(p_vet uuid)
returns table (id uuid, starts_at timestamptz)
language sql stable security definer set search_path = public as $$
  select s.id, s.starts_at
  from public.slots s
  where s.vet_id = p_vet
    and public.is_verified_vet(p_vet)
    and s.starts_at > now()
    and not exists (select 1 from public.appointments a where a.slot_id = s.id and a.status <> 'cancelled')
  order by s.starts_at
  limit 200
$$;

-- The owner's submitted cases that do not already have a live booking.
create function public.bookable_cases()
returns table (id uuid, case_number text, animal_name text)
language sql stable security definer set search_path = public as $$
  select c.id, c.case_number, an.name
  from public.cases c
  join public.animals an on an.id = c.animal_id
  where c.owner_id = auth.uid()
    and c.status = 'submitted'
    and not exists (select 1 from public.appointments a where a.case_id = c.id and a.status = 'booked')
  order by c.submitted_at desc
$$;

create function public.book_appointment(p_slot uuid, p_case uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  c public.cases;
  s public.slots;
  new_id uuid;
begin
  select * into c from public.cases where id = p_case;
  if not found or c.owner_id <> auth.uid() then
    raise exception 'case_not_found';
  end if;
  if c.status <> 'submitted' then
    raise exception 'case_not_submitted';
  end if;
  if exists (select 1 from public.appointments where case_id = p_case and status = 'booked') then
    raise exception 'case_already_booked';
  end if;

  select * into s from public.slots where id = p_slot for update;
  if not found
     or s.starts_at <= now()
     or not public.is_verified_vet(s.vet_id)
     or exists (select 1 from public.appointments where slot_id = p_slot and status <> 'cancelled') then
    raise exception 'slot_unavailable';
  end if;

  insert into public.appointments (slot_id, starts_at, case_id, owner_id, vet_id)
  values (s.id, s.starts_at, c.id, c.owner_id, s.vet_id)
  returning id into new_id;

  perform public.notify(s.vet_id, 'booking', 'موعد جديد', 'تم حجز موعد جديد معك.', '/vet/appointments');
  return new_id;
exception
  when unique_violation then
    raise exception 'slot_unavailable';
end;
$$;

-- The owner's appointments (upcoming and past) for the appointments tab and detail page.
create function public.my_appointments(p_appointment uuid default null)
returns table (
  id uuid,
  case_id uuid,
  case_number text,
  animal_name text,
  vet_id uuid,
  vet_name text,
  starts_at timestamptz,
  status public.appointment_status,
  ended_at timestamptz,
  has_outcome boolean
)
language sql stable security definer set search_path = public as $$
  select a.id, a.case_id, c.case_number, an.name, a.vet_id, p.full_name, a.starts_at, a.status, a.ended_at,
         exists (select 1 from public.consultation_outcomes o where o.appointment_id = a.id and o.status = 'approved')
  from public.appointments a
  join public.cases c on c.id = a.case_id
  join public.animals an on an.id = c.animal_id
  join public.profiles p on p.id = a.vet_id
  where a.owner_id = auth.uid()
    and (p_appointment is null or a.id = p_appointment)
  order by a.starts_at
$$;

create policy appointments_owner_select on public.appointments
  for select to authenticated using (owner_id = auth.uid());

create policy appointments_vet_select on public.appointments
  for select to authenticated using (vet_id = auth.uid());
