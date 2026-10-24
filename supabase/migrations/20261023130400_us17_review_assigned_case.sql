-- US-17 Review an Assigned Case.
-- A veterinarian can read a case, its animal, attachments and recording only while they hold
-- (or held) an appointment for that case. Any other case is refused by these policies.

create function public.is_assigned_vet(p_case uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.appointments
    where case_id = p_case and vet_id = auth.uid() and status in ('booked', 'completed')
  )
$$;

create function public.can_vet_see_animal(p_animal uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.appointments a join public.cases c on c.id = a.case_id
    where c.animal_id = p_animal and a.vet_id = auth.uid() and a.status in ('booked', 'completed')
  )
$$;

-- Storage paths are <owner id>/<case id>/<file>; the second folder must be a case assigned to this veterinarian.
create function public.is_assigned_vet_path(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  folder text := split_part(p_name, '/', 2);
begin
  if folder !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return public.is_assigned_vet(folder::uuid);
end;
$$;

create policy cases_vet_select on public.cases
  for select to authenticated using (public.is_assigned_vet(id));

create policy animals_vet_select on public.animals
  for select to authenticated using (public.can_vet_see_animal(id));

create policy case_media_vet_select on public.case_media
  for select to authenticated using (public.is_assigned_vet(case_id));

create policy case_files_vet_read on storage.objects
  for select to authenticated
  using (bucket_id in ('case-media', 'case-voice') and public.is_assigned_vet_path(name));
