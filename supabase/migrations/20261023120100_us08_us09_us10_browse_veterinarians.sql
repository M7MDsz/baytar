-- US-08 Browse, US-09 Filter, US-10 View a Veterinarian Profile.
-- Only verified veterinarians with an unexpired license are ever returned.

create function public.next_free_slot(p_vet uuid) returns timestamptz
language sql stable security definer set search_path = public as $$
  select min(s.starts_at)
  from public.slots s
  where s.vet_id = p_vet and s.starts_at > now()
    and not exists (select 1 from public.appointments a where a.slot_id = s.id and a.status <> 'cancelled')
$$;

create function public.list_vets(
  p_specialty text default null,
  p_animal_type text default null,
  p_language text default null,
  p_within_days int default null
)
returns table (
  id uuid,
  full_name text,
  specialties text[],
  animal_types text[],
  languages text[],
  next_available timestamptz
)
language sql stable security definer set search_path = public as $$
  select v.id, p.full_name, v.specialties, v.animal_types, v.languages, public.next_free_slot(v.id)
  from public.vet_profiles v
  join public.profiles p on p.id = v.id
  where v.status = 'verified'
    and v.license_expiry >= current_date
    and (p_specialty is null or p_specialty = any (v.specialties))
    and (p_animal_type is null or p_animal_type = any (v.animal_types))
    and (p_language is null or p_language = any (v.languages))
    and (
      p_within_days is null
      or exists (
        select 1 from public.slots s
        where s.vet_id = v.id
          and s.starts_at > now()
          and s.starts_at < now() + make_interval(days => p_within_days)
          and not exists (select 1 from public.appointments a where a.slot_id = s.id and a.status <> 'cancelled')
      )
    )
  order by public.next_free_slot(v.id) nulls last, p.full_name
$$;

-- Ratings arrive with US-38 (Sprint 2); until then rating is null and the app hides it.
create function public.vet_public_profile(p_vet uuid)
returns table (
  id uuid,
  full_name text,
  specialties text[],
  animal_types text[],
  languages text[],
  bio text,
  license_number text,
  license_expiry date,
  next_available timestamptz,
  rating numeric
)
language sql stable security definer set search_path = public as $$
  select v.id, p.full_name, v.specialties, v.animal_types, v.languages, v.bio,
         v.license_number, v.license_expiry, public.next_free_slot(v.id), null::numeric
  from public.vet_profiles v
  join public.profiles p on p.id = v.id
  where v.id = p_vet and v.status = 'verified' and v.license_expiry >= current_date
$$;
