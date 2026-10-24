-- US-33 Publish Available Time Slots.
-- 30-minute slots; overlaps are stopped by the slots_no_overlap constraint; booked slots cannot be removed.

create policy slots_vet_select_own on public.slots
  for select to authenticated using (vet_id = auth.uid());

-- Adds one slot, or the same slot weekly for p_weeks more weeks (0-4). All or nothing.
create function public.add_slots(p_starts_at timestamptz, p_weeks int default 0) returns int
language plpgsql security definer set search_path = public as $$
declare
  i int;
  s timestamptz;
begin
  if not public.is_verified_vet(auth.uid()) then
    raise exception 'vet_not_verified';
  end if;
  if p_weeks < 0 or p_weeks > 4 then
    raise exception 'bad_repeat';
  end if;
  if p_starts_at <= now() then
    raise exception 'slot_in_past';
  end if;
  for i in 0..p_weeks loop
    s := p_starts_at + make_interval(weeks => i);
    begin
      insert into public.slots (vet_id, starts_at, ends_at) values (auth.uid(), s, s + interval '30 minutes');
    exception when exclusion_violation then
      raise exception 'slot_overlaps';
    end;
  end loop;
  return p_weeks + 1;
end;
$$;

create function public.delete_slot(p_slot uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.slots where id = p_slot and vet_id = auth.uid()) then
    raise exception 'slot_not_found';
  end if;
  if exists (select 1 from public.appointments where slot_id = p_slot and status <> 'cancelled') then
    raise exception 'slot_booked';
  end if;
  delete from public.slots where id = p_slot;
end;
$$;

-- The veterinarian's own schedule from today on, with booked and free slots told apart.
create function public.my_schedule()
returns table (id uuid, starts_at timestamptz, ends_at timestamptz, booked boolean)
language sql stable security definer set search_path = public as $$
  select s.id, s.starts_at, s.ends_at,
         exists (select 1 from public.appointments a where a.slot_id = s.id and a.status <> 'cancelled')
  from public.slots s
  where s.vet_id = auth.uid() and s.ends_at > date_trunc('day', now())
  order by s.starts_at
$$;
