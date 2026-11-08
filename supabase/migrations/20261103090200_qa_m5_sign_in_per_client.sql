-- QA M-5: the sign-in lockout (US-30) was keyed on the email alone, so 5 wrong passwords from anywhere locked the
-- real owner out. The sign-in Edge Function now keeps two counters (rules in supabase/functions/sign-in/attempts.ts):
--   * login_attempts_by_client: 5 failures in a row for one account from one client lock that client out of that
--     account for 15 minutes (the US-30 rule as the user meets it);
--   * login_attempts (existing): failures for the account from all clients within a 15-minute window; 20 lock the
--     account everywhere for 15 minutes, so guessing from many addresses stays bounded.
-- The client is stored as a SHA-256 of the caller's address, never the address itself.

create table public.login_attempts_by_client (
  email text not null,
  client text not null,
  failures int not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (email, client)
);

-- No policies: only the sign-in Edge Function (service role) reads and writes the counters.
alter table public.login_attempts_by_client enable row level security;

alter table public.login_attempts add column window_started_at timestamptz;

-- Old counters are kept only while they can still matter.
select cron.schedule(
  'prune-login-attempts',
  '17 3 * * *',
  $$delete from public.login_attempts_by_client
      where updated_at < now() - interval '1 day' and (locked_until is null or locked_until < now());
    delete from public.login_attempts
      where updated_at < now() - interval '1 day' and (locked_until is null or locked_until < now());$$
);
