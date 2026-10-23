-- US-01 Create an Animal Profile, US-02 Edit an Animal Profile.
-- An owner can only see and change their own animals; photos live in a private bucket under the owner's id.

create policy animals_owner_select on public.animals
  for select to authenticated using (owner_id = auth.uid());

create policy animals_owner_insert on public.animals
  for insert to authenticated with check (owner_id = auth.uid() and public.my_role() = 'owner');

create policy animals_owner_update on public.animals
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('animal-photos', 'animal-photos', false, 10485760, array['image/jpeg', 'image/png']);

create policy animal_photos_owner_rw on storage.objects
  for all to authenticated
  using (bucket_id = 'animal-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'animal-photos' and (storage.foldername(name))[1] = auth.uid()::text);
