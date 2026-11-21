-- US-15 Change the Consultation Communication Mode.
-- During a consultation the owner can move between video, voice only and text messages without leaving it: the video
-- room stays connected and the app only turns the camera and microphone off or on. The owner's current mode is kept on
-- the appointment and announced in the consultation's message stream, so the veterinarian sees the change at once.
-- Text messages belong to the appointment and only its owner and veterinarian can read them.

alter table public.appointments
  add column owner_mode text not null default 'video' check (owner_mode in ('video', 'voice', 'text')),
  add column owner_mode_at timestamptz;

create table public.consultation_messages (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  -- 'text' is a message; 'mode' records the owner's new mode (body = video, voice or text).
  kind text not null default 'text' check (kind in ('text', 'mode')),
  body text not null check (btrim(body) <> '' and char_length(body) <= 1000),
  created_at timestamptz not null default now()
);

create index consultation_messages_appointment on public.consultation_messages (appointment_id, created_at);

alter table public.consultation_messages enable row level security;

create function public.is_consultation_party(p_appointment uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.appointments where id = p_appointment and auth.uid() in (owner_id, vet_id))
$$;

create policy consultation_messages_party_select on public.consultation_messages
  for select to authenticated using (public.is_consultation_party(appointment_id));

-- Messages are written only through the functions below.
revoke insert, update, delete on public.consultation_messages from anon, authenticated;

alter publication supabase_realtime add table public.consultation_messages;

-- The appointment, if the caller is in it now: they joined it (US-14, US-19), the veterinarian has not ended it, and
-- it started less than 90 minutes ago. Anyone else gets not_in_consultation.
create function public.live_consultation_for_caller(p_appointment uuid) returns public.appointments
language plpgsql stable security definer set search_path = public as $$
declare
  a public.appointments;
begin
  select * into a from public.appointments where id = p_appointment;
  if not found
     or a.status <> 'booked'
     or a.ended_at is not null
     or now() >= a.starts_at + interval '90 minutes'
     or not ((a.owner_id = auth.uid() and a.owner_joined_at is not null)
          or (a.vet_id = auth.uid() and a.vet_joined_at is not null)) then
    raise exception 'not_in_consultation';
  end if;
  return a;
end;
$$;

revoke execute on function public.live_consultation_for_caller(uuid) from public, anon, authenticated;

-- The owner switches mode. Returns the mode now in force. Choosing the current mode again changes nothing.
create function public.set_consultation_mode(p_appointment uuid, p_mode text) returns text
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
begin
  if p_mode is null or p_mode not in ('video', 'voice', 'text') then
    raise exception 'bad_mode';
  end if;
  a := public.live_consultation_for_caller(p_appointment);
  if a.owner_id <> auth.uid() then
    raise exception 'owner_only';
  end if;
  if a.owner_mode = p_mode then
    return p_mode;
  end if;
  update public.appointments set owner_mode = p_mode, owner_mode_at = now() where id = a.id;
  insert into public.consultation_messages (appointment_id, sender_id, kind, body) values (a.id, auth.uid(), 'mode', p_mode);
  return p_mode;
end;
$$;

-- Either side sends a text message (trimmed, at most 1000 characters). Returns its id.
create function public.send_consultation_message(p_appointment uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
  t text := btrim(coalesce(p_body, ''));
  v_id uuid;
begin
  if t = '' then
    raise exception 'empty_message';
  end if;
  if char_length(t) > 1000 then
    raise exception 'message_too_long';
  end if;
  a := public.live_consultation_for_caller(p_appointment);
  insert into public.consultation_messages (appointment_id, sender_id, kind, body)
    values (a.id, auth.uid(), 'text', t)
    returning id into v_id;
  return v_id;
end;
$$;
