-- US-34 View Upcoming Appointments (veterinarian).
-- Returns only the calling veterinarian's own live bookings, soonest first, with just the fields the list shows
-- (the owner's first name, never their contact details). Cancelled bookings drop out; rescheduled ones carry the new time.

create function public.vet_upcoming_appointments()
returns table (
  appointment_id uuid,
  case_id uuid,
  starts_at timestamptz,
  animal_name text,
  species text,
  owner_first_name text
)
language sql stable security definer set search_path = public as $$
  select a.id, a.case_id, a.starts_at, an.name, an.species, split_part(btrim(p.full_name), ' ', 1)
  from public.appointments a
  join public.cases c on c.id = a.case_id
  join public.animals an on an.id = c.animal_id
  join public.profiles p on p.id = a.owner_id
  where a.vet_id = auth.uid()
    and a.status = 'booked'
    and a.ended_at is null
    and a.starts_at + interval '30 minutes' > now()
  order by a.starts_at
$$;
