-- Veterinarian gender for the doctor avatars (طبيب / طبيبة).
-- Nullable: veterinarians registered before this migration show a neutral avatar until it is set.
-- The functions below are re-created unchanged except for the new output columns (and p_gender on
-- register_vet_profile, defaulting to null so older app builds keep working).

alter table public.vet_profiles add column gender text check (gender in ('male', 'female'));

-- US-08, US-09: same filters and order as before, plus the gender.
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
  gender text
)
language sql stable security definer set search_path = public as $$
  select v.id, p.full_name, v.specialties, v.animal_types, v.languages, public.next_free_slot(v.id), v.gender
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

-- US-10: same as before, plus the gender.
drop function public.vet_public_profile(uuid);
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
  rating numeric,
  gender text
)
language sql stable security definer set search_path = public as $$
  select v.id, p.full_name, v.specialties, v.animal_types, v.languages, v.bio,
         v.license_number, v.license_expiry, public.next_free_slot(v.id), null::numeric, v.gender
  from public.vet_profiles v
  join public.profiles p on p.id = v.id
  where v.id = p_vet and v.status = 'verified' and v.license_expiry >= current_date
$$;

-- US-11: the owner's appointments, plus the vet's gender and the animal's species for the avatars.
drop function public.my_appointments(uuid);
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
  has_outcome boolean,
  vet_gender text,
  animal_species text
)
language sql stable security definer set search_path = public as $$
  select a.id, a.case_id, c.case_number, an.name, a.vet_id, p.full_name, a.starts_at, a.status, a.ended_at,
         exists (select 1 from public.consultation_outcomes o where o.appointment_id = a.id and o.status = 'approved'),
         vp.gender, an.species::text
  from public.appointments a
  join public.cases c on c.id = a.case_id
  join public.animals an on an.id = c.animal_id
  join public.profiles p on p.id = a.vet_id
  left join public.vet_profiles vp on vp.id = a.vet_id
  where a.owner_id = auth.uid()
    and (p_appointment is null or a.id = p_appointment)
  order by a.starts_at
$$;

-- US-32: pending registrations for the administrator, plus the gender.
drop function public.pending_vets();
create function public.pending_vets()
returns table (
  id uuid,
  full_name text,
  email text,
  mobile text,
  license_number text,
  license_expiry date,
  license_path text,
  specialties text[],
  animal_types text[],
  languages text[],
  bio text,
  created_at timestamptz,
  gender text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden';
  end if;
  return query
    select v.id, p.full_name, p.email, p.mobile, v.license_number, v.license_expiry, v.license_path,
           v.specialties, v.animal_types, v.languages, v.bio, v.created_at, v.gender
    from public.vet_profiles v
    join public.profiles p on p.id = v.id
    where v.status = 'pending'
    order by v.created_at asc;
end;
$$;

-- US-31: same checks as before; the gender is stored when given.
drop function public.register_vet_profile(text, date, text, text[], text[], text[], text);
create function public.register_vet_profile(
  p_license_number text,
  p_license_expiry date,
  p_license_path text,
  p_specialties text[],
  p_animal_types text[],
  p_languages text[],
  p_bio text default null,
  p_gender text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() is distinct from 'vet' then
    raise exception 'not_a_vet_account';
  end if;
  if exists (select 1 from public.vet_profiles where id = auth.uid()) then
    raise exception 'already_registered';
  end if;
  if btrim(coalesce(p_license_number, '')) = '' or p_license_path is null
     or coalesce(cardinality(p_specialties), 0) = 0
     or coalesce(cardinality(p_animal_types), 0) = 0
     or coalesce(cardinality(p_languages), 0) = 0 then
    raise exception 'missing_fields';
  end if;
  if p_gender is not null and p_gender not in ('male', 'female') then
    raise exception 'invalid_gender';
  end if;
  if p_license_expiry is null or p_license_expiry <= current_date then
    raise exception 'license_expiry_not_future';
  end if;
  if split_part(p_license_path, '/', 1) <> auth.uid()::text then
    raise exception 'bad_license_path';
  end if;
  insert into public.vet_profiles
    (id, license_number, license_expiry, license_path, specialties, animal_types, languages, bio, gender)
  values
    (auth.uid(), upper(btrim(p_license_number)), p_license_expiry, p_license_path,
     p_specialties, p_animal_types, p_languages, nullif(btrim(coalesce(p_bio, '')), ''), p_gender);
exception
  when unique_violation then
    raise exception 'license_taken';
end;
$$;
