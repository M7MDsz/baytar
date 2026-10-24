-- US-03 Enter a Written Case Description, US-05 Attach Case Media, US-06 Save a Case as a Draft.
-- Owners create and edit their own cases while they are drafts. Sending a case (case number, status)
-- is done only by the submit_case function (US-07), never by a direct update.

create policy cases_owner_select on public.cases
  for select to authenticated using (owner_id = auth.uid());

create policy cases_owner_insert on public.cases
  for insert to authenticated
  with check (
    owner_id = auth.uid() and status = 'draft'
    and exists (select 1 from public.animals a where a.id = animal_id and a.owner_id = auth.uid())
  );

create policy cases_owner_update_draft on public.cases
  for update to authenticated
  using (owner_id = auth.uid() and status = 'draft')
  with check (
    owner_id = auth.uid() and status = 'draft'
    and exists (select 1 from public.animals a where a.id = animal_id and a.owner_id = auth.uid())
  );

create policy cases_owner_delete_draft on public.cases
  for delete to authenticated using (owner_id = auth.uid() and status = 'draft');

revoke insert, update on public.cases from anon, authenticated;
grant insert (animal_id, description, voice_path) on public.cases to authenticated;
grant update (animal_id, description, voice_path) on public.cases to authenticated;

create function public.owns_draft_case(p_case uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.cases where id = p_case and owner_id = auth.uid() and status = 'draft')
$$;

create policy case_media_owner_select on public.case_media
  for select to authenticated
  using (exists (select 1 from public.cases c where c.id = case_id and c.owner_id = auth.uid()));

create policy case_media_owner_insert on public.case_media
  for insert to authenticated with check (public.owns_draft_case(case_id));

create policy case_media_owner_delete on public.case_media
  for delete to authenticated using (public.owns_draft_case(case_id));

-- JPG/PNG photos and MP4 videos up to 30 MB, stored as <owner id>/<case id>/<file>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('case-media', 'case-media', false, 31457280, array['image/jpeg', 'image/png', 'video/mp4']);

create policy case_media_files_owner_rw on storage.objects
  for all to authenticated
  using (bucket_id = 'case-media' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'case-media' and (storage.foldername(name))[1] = auth.uid()::text);
