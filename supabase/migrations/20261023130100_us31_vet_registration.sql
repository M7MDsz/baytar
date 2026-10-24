-- US-31 Register as a Veterinarian.
-- The account is created through Supabase Auth with role 'vet' (US-29 trigger). After the email code is entered,
-- the app uploads the license and calls register_vet_profile. New registrations are Pending verification.

create function public.license_number_taken(p_number text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.vet_profiles where upper(btrim(license_number)) = upper(btrim(p_number)))
$$;

create function public.register_vet_profile(
  p_license_number text,
  p_license_expiry date,
  p_license_path text,
  p_specialties text[],
  p_animal_types text[],
  p_languages text[],
  p_bio text default null
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
  if p_license_expiry is null or p_license_expiry <= current_date then
    raise exception 'license_expiry_not_future';
  end if;
  if split_part(p_license_path, '/', 1) <> auth.uid()::text then
    raise exception 'bad_license_path';
  end if;
  insert into public.vet_profiles
    (id, license_number, license_expiry, license_path, specialties, animal_types, languages, bio)
  values
    (auth.uid(), upper(btrim(p_license_number)), p_license_expiry, p_license_path,
     p_specialties, p_animal_types, p_languages, nullif(btrim(coalesce(p_bio, '')), ''));
exception
  when unique_violation then
    raise exception 'license_taken';
end;
$$;

create policy vet_profiles_self_select on public.vet_profiles
  for select to authenticated using (id = auth.uid());

-- License files: PDF, JPG or PNG up to 10 MB, private, under the veterinarian's id.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('licenses', 'licenses', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png']);

create policy licenses_vet_rw on storage.objects
  for all to authenticated
  using (bucket_id = 'licenses' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'licenses' and (storage.foldername(name))[1] = auth.uid()::text);
