-- QA H-1: a device's push token belongs to the account signed in on that device, and to no other account.
-- Before this, signing out left the token on the old profile, so the next account signed in on the same phone also
-- received the old account's notifications. The app now saves the token through set_push_token, which first takes it
-- off any other profile, and calls set_push_token(null) on sign-out (US-30: after sign-out the account's data is no
-- longer shown on the device).

create function public.set_push_token(p_token text) returns void
language plpgsql security definer set search_path = public as $$
declare
  t text := nullif(btrim(p_token), '');
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  if t is not null then
    update public.profiles set fcm_token = null where fcm_token = t and id <> auth.uid();
  end if;
  update public.profiles set fcm_token = t where id = auth.uid();
end;
$$;

revoke execute on function public.set_push_token(text) from public, anon;
grant execute on function public.set_push_token(text) to authenticated;
