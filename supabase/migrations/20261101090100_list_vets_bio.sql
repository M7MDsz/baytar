-- US-08 vet list: also return the vet's short bio, for the two-line excerpt on each vet card.
-- Same filters, order and security as the vet_gender version; only the bio column is added.

drop function public.list_vets(text, text, text, int);
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
  next_available timestamptz,
  gender text,
  bio text
)
language sql stable security definer set search_path = public as $$
  select v.id, p.full_name, v.specialties, v.animal_types, v.languages, public.next_free_slot(v.id), v.gender, v.bio
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
