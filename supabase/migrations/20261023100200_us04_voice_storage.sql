-- US-04 Record a Voice Case Description.
-- Recordings are stored privately as <owner id>/<case id>/<file>.m4a.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('case-voice', 'case-voice', false, 15728640, array['audio/mp4', 'audio/m4a', 'audio/aac']);

create policy case_voice_owner_rw on storage.objects
  for all to authenticated
  using (bucket_id = 'case-voice' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'case-voice' and (storage.foldername(name))[1] = auth.uid()::text);
