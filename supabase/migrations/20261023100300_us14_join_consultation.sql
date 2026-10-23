-- US-14 Join a Virtual Consultation (owner side).
-- Returns 'ok' or the reason entry is refused: not_found, forbidden, cancelled, too_early, too_late.
-- The consultation-token Edge Function calls this as the signed-in user before it issues a video token.

create function public.join_consultation(p_appointment uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
begin
  select * into a from public.appointments where id = p_appointment for update;
  if not found then
    return 'not_found';
  end if;
  if a.owner_id <> auth.uid() then
    return 'forbidden';
  end if;
  if a.status = 'cancelled' then
    return 'cancelled';
  end if;
  -- Someone who already joined may reconnect until the 30-minute slot ends.
  if not (a.owner_joined_at is not null and a.ended_at is null and now() < a.starts_at + interval '30 minutes') then
    if now() < a.starts_at - interval '10 minutes' then
      return 'too_early';
    end if;
    if now() > a.starts_at + interval '15 minutes' or a.ended_at is not null then
      return 'too_late';
    end if;
  end if;
  update public.appointments set owner_joined_at = coalesce(owner_joined_at, now()) where id = a.id;
  return 'ok';
end;
$$;
