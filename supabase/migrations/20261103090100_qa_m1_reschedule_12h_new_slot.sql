-- QA M-1: the 12-hour rule of US-12 also applies to the NEW time. Before this, an appointment three days away could
-- be moved to a slot starting in 30 minutes. Identical to 20261023130300 except for the new slot's guard
-- (s.starts_at <= now() + 12 hours, the same boundary as the old appointment's). The app's picker hides those slots.

create or replace function public.reschedule_appointment(p_appointment uuid, p_new_slot uuid) returns void
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
     or s.starts_at <= now() + interval '12 hours'
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
