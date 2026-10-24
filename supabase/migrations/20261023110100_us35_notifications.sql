-- US-35 Receive Notifications.
-- Other stories call public.notify(...). Each row shows in the in-app list (realtime) and, through a trigger,
-- asks the push-dispatch Edge Function to send a push that carries no medical details.

create function public.notify(p_user uuid, p_kind text, p_title text, p_body text, p_route text default null)
returns void
language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, kind, title, body, route)
  values (p_user, p_kind, p_title, p_body, p_route)
$$;

-- Only database functions may create notifications, never the app directly.
revoke execute on function public.notify(uuid, text, text, text, text) from public, anon, authenticated;

create policy notifications_self_select on public.notifications
  for select to authenticated using (user_id = auth.uid());

create policy notifications_self_update on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

alter publication supabase_realtime add table public.notifications;

-- Push: app_config holds push_url (the push-dispatch function URL) and push_secret (shared secret).
create extension if not exists pg_net with schema extensions;

create function public.push_notification() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_url text := (select value from public.app_config where key = 'push_url');
  v_secret text := (select value from public.app_config where key = 'push_secret');
begin
  if v_url is not null then
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object('notification_id', new.id),
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_secret)
    );
  end if;
  return new;
end;
$$;

create trigger notifications_push
  after insert on public.notifications
  for each row execute function public.push_notification();

-- Reminder 15 minutes before every appointment, for the owner and the veterinarian.
create function public.send_due_reminders() returns int
language plpgsql security definer set search_path = public as $$
declare
  a record;
  n int := 0;
begin
  for a in
    select id, owner_id, vet_id from public.appointments
    where status = 'booked' and reminder_sent_at is null
      and starts_at > now() and starts_at <= now() + interval '15 minutes'
    for update skip locked
  loop
    perform public.notify(a.owner_id, 'reminder', 'تذكير بموعد', 'استشارتك تبدأ خلال 15 دقيقة.', '/appointments/' || a.id);
    perform public.notify(a.vet_id, 'reminder', 'تذكير بموعد', 'لديك استشارة تبدأ خلال 15 دقيقة.', '/vet/appointments');
    update public.appointments set reminder_sent_at = now() where id = a.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

revoke execute on function public.send_due_reminders() from public, anon, authenticated;

create extension if not exists pg_cron;
select cron.schedule('appointment-reminders', '* * * * *', 'select public.send_due_reminders()');
