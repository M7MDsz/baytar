-- US-12 Reschedule an Appointment, US-13 Cancel an Appointment.
-- Both are allowed only while the appointment starts more than 12 hours from now.
-- A failed reschedule raises, so the transaction rolls back and the original booking stays as it was.

create function public.reschedule_appointment(p_appointment uuid, p_new_slot uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
  s public.slots;
begin
  select * into a from public.appointments where id = p_appointment for update;
  if not found or a.owner_id <> auth.uid() then
    raise exception 'appointment_not_found';
  end if;
  if a.status <> 'booked' then
    raise exception 'not_booked';
  end if;
  if a.starts_at <= now() + interval '12 hours' then
    raise exception 'too_late_to_change';
  end if;

  select * into s from public.slots where id = p_new_slot for update;
  if not found
     or s.vet_id <> a.vet_id
     or s.starts_at <= now()
     or exists (select 1 from public.appointments where slot_id = s.id and status <> 'cancelled') then
    raise exception 'slot_unavailable';
  end if;

  update public.appointments
    set slot_id = s.id, starts_at = s.starts_at, rescheduled_at = now(), reminder_sent_at = null
    where id = a.id;

  perform public.notify(a.vet_id, 'reschedule', 'تغيير موعد', 'غيّر المالك موعد استشارة معك.', '/vet/appointments');
exception
  when unique_violation then
    raise exception 'slot_unavailable';
end;
$$;

create function public.cancel_appointment(p_appointment uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
begin
  select * into a from public.appointments where id = p_appointment for update;
  if not found or a.owner_id <> auth.uid() then
    raise exception 'appointment_not_found';
  end if;
  if a.status <> 'booked' then
    raise exception 'not_booked';
  end if;
  if a.starts_at <= now() + interval '12 hours' then
    raise exception 'too_late_to_change';
  end if;
  -- The partial unique index only covers 'booked', so the slot is free for other owners again.
  update public.appointments set status = 'cancelled', cancelled_at = now() where id = a.id;
  perform public.notify(a.vet_id, 'cancellation', 'إلغاء موعد', 'ألغى المالك موعد استشارة معك.', '/vet/appointments');
end;
$$;
