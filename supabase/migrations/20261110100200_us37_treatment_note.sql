-- US-37 Issue a Treatment Note.
-- After a consultation its own veterinarian can issue a treatment note: care instructions and any prescribed medicines,
-- each with its name, dose, frequency and duration, all written by the veterinarian (nothing here reads the AI summary
-- or fills anything in). An issued note shows the veterinarian's name, license number and issue date and can never be
-- changed; a correction is issued as a new note that points to the one it corrects, and both stay in the record. The
-- owner is notified and reads the notes with the outcome (US-16) and the consultation record (US-23).

create table public.treatment_notes (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments (id) on delete cascade,
  case_id uuid not null references public.cases (id) on delete cascade,
  vet_id uuid not null references public.vet_profiles (id),
  vet_name text not null,
  license_number text not null,
  care_instructions text check (
    care_instructions is null or (btrim(care_instructions) <> '' and char_length(care_instructions) <= 2000)
  ),
  corrects_note_id uuid references public.treatment_notes (id),
  issued_at timestamptz not null default now()
);

create index treatment_notes_appointment on public.treatment_notes (appointment_id, issued_at);

create table public.treatment_note_medicines (
  note_id uuid not null references public.treatment_notes (id) on delete cascade,
  position smallint not null check (position between 1 and 20),
  name text not null check (btrim(name) <> '' and char_length(name) <= 120),
  dose text not null check (btrim(dose) <> '' and char_length(dose) <= 120),
  frequency text not null check (btrim(frequency) <> '' and char_length(frequency) <= 120),
  duration text not null check (btrim(duration) <> '' and char_length(duration) <= 120),
  primary key (note_id, position)
);

alter table public.treatment_notes enable row level security;
alter table public.treatment_note_medicines enable row level security;

-- The appointment's owner and its veterinarian can read its notes; nobody can write them except issue_treatment_note.
create policy treatment_notes_party_select on public.treatment_notes
  for select to authenticated using (public.is_consultation_party(appointment_id));

create policy treatment_note_medicines_party_select on public.treatment_note_medicines
  for select to authenticated using (
    exists (select 1 from public.treatment_notes n where n.id = note_id and public.is_consultation_party(n.appointment_id))
  );

revoke insert, update, delete on public.treatment_notes, public.treatment_note_medicines from anon, authenticated;

-- An issued note is final: nobody can change it. Only server maintenance (the service role, or the database owner when
-- a whole rehearsal consultation is removed by the class-demo reset) can delete it, together with its consultation.
create function public.refuse_note_change() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' and current_user in ('service_role', 'postgres', 'supabase_admin') then
    return old;
  end if;
  raise exception 'note_is_final';
end;
$$;

create trigger treatment_notes_final before update or delete on public.treatment_notes
  for each row execute function public.refuse_note_change();
create trigger treatment_note_medicines_final before update or delete on public.treatment_note_medicines
  for each row execute function public.refuse_note_change();

-- p_medicines is a JSON list of {name, dose, frequency, duration}; every field is required for every medicine.
-- A note needs care instructions, at least one medicine, or both. p_corrects is the earlier note of the same
-- consultation that this one corrects. Returns the new note's id.
create function public.issue_treatment_note(
  p_appointment uuid,
  p_care_instructions text,
  p_medicines jsonb default '[]',
  p_corrects uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
  v_instructions text := nullif(btrim(coalesce(p_care_instructions, '')), '');
  v_medicines jsonb := coalesce(p_medicines, '[]');
  m jsonb;
  i int := 0;
  v_id uuid;
begin
  select * into a from public.appointments where id = p_appointment;
  if not found or a.vet_id <> auth.uid() then
    raise exception 'not_responsible_vet';
  end if;
  if a.status = 'cancelled' or a.started_at is null then
    raise exception 'consultation_not_started';
  end if;
  if jsonb_typeof(v_medicines) <> 'array' or jsonb_array_length(v_medicines) > 20 then
    raise exception 'bad_medicines';
  end if;
  for m in select value from jsonb_array_elements(v_medicines) loop
    if jsonb_typeof(m) <> 'object'
       or btrim(coalesce(m ->> 'name', '')) = ''
       or btrim(coalesce(m ->> 'dose', '')) = ''
       or btrim(coalesce(m ->> 'frequency', '')) = ''
       or btrim(coalesce(m ->> 'duration', '')) = '' then
      raise exception 'medicine_incomplete';
    end if;
  end loop;
  if v_instructions is null and jsonb_array_length(v_medicines) = 0 then
    raise exception 'note_empty';
  end if;
  if p_corrects is not null
     and not exists (select 1 from public.treatment_notes where id = p_corrects and appointment_id = a.id) then
    raise exception 'bad_correction';
  end if;

  insert into public.treatment_notes
    (appointment_id, case_id, vet_id, vet_name, license_number, care_instructions, corrects_note_id)
  select a.id, a.case_id, a.vet_id, p.full_name, v.license_number, v_instructions, p_corrects
  from public.vet_profiles v
  join public.profiles p on p.id = v.id
  where v.id = a.vet_id
  returning id into v_id;

  for m in select value from jsonb_array_elements(v_medicines) loop
    i := i + 1;
    insert into public.treatment_note_medicines (note_id, position, name, dose, frequency, duration)
    values (v_id, i, btrim(m ->> 'name'), btrim(m ->> 'dose'), btrim(m ->> 'frequency'), btrim(m ->> 'duration'));
  end loop;

  -- The push carries no medical details (US-35).
  perform public.notify(
    a.owner_id, 'treatment_note',
    case when p_corrects is null then 'ملاحظة علاج جديدة' else 'تصحيح لملاحظة العلاج' end,
    'أصدر الطبيب ملاحظة علاج لاستشارتك. افتحها لتعرف طريقة العناية.',
    '/outcomes/' || a.id
  );
  return v_id;
end;
$$;

-- The notes of one consultation, oldest first, each with its medicines in order. For its owner and veterinarian only
-- (anyone else gets no rows).
create function public.treatment_notes_for(p_appointment uuid)
returns table (
  id uuid,
  appointment_id uuid,
  vet_name text,
  license_number text,
  care_instructions text,
  corrects_note_id uuid,
  issued_at timestamptz,
  medicines jsonb
)
language sql stable security definer set search_path = public as $$
  select n.id, n.appointment_id, n.vet_name, n.license_number, n.care_instructions, n.corrects_note_id, n.issued_at,
         coalesce((
           select jsonb_agg(jsonb_build_object('name', m.name, 'dose', m.dose, 'frequency', m.frequency,
                                               'duration', m.duration) order by m.position)
           from public.treatment_note_medicines m
           where m.note_id = n.id
         ), '[]')
  from public.treatment_notes n
  where n.appointment_id = p_appointment and public.is_consultation_party(p_appointment)
  order by n.issued_at, n.id
$$;
