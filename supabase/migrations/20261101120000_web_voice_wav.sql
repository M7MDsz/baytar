-- Web demo: browsers record the voice description as WAV (AAC recording is not available in every browser),
-- so the voice bucket also accepts audio/wav. Phones keep uploading AAC in .m4a.
update storage.buckets
set allowed_mime_types = array['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/wav']
where id = 'case-voice';
