-- US-29 Create an Owner Account (also used by US-31 for veterinarians).
-- Supabase Auth holds the email and password and sends the 6-digit code (config.toml: otp_length, otp_expiry).
-- This trigger creates the matching profile, and refuses the sign-up when the terms of use were not accepted.

alter table public.profiles
  add constraint profiles_mobile_format check (mobile is null or mobile ~ '^05[0-9]{8}$');

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce((meta ->> 'terms_accepted')::boolean, false) is not true then
    raise exception 'terms_not_accepted';
  end if;
  insert into public.profiles (id, role, full_name, email, mobile, terms_accepted_at)
  values (
    new.id,
    -- Only owner or vet can be chosen at sign-up; administrators are promoted by hand (see README).
    case when meta ->> 'role' = 'vet' then 'vet'::public.user_role else 'owner'::public.user_role end,
    coalesce(nullif(btrim(meta ->> 'full_name'), ''), split_part(new.email, '@', 1)),
    new.email,
    nullif(meta ->> 'mobile', ''),
    now()
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create policy profiles_self_select on public.profiles
  for select to authenticated using (id = auth.uid());

create policy profiles_self_update on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Users may change only these columns of their own profile (never their role).
revoke update on public.profiles from anon, authenticated;
grant update (full_name, mobile, push_enabled, fcm_token) on public.profiles to authenticated;
