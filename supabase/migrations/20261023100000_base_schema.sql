-- Baytar data model (Sprint 0 setup).
-- Row level security is switched on for every table with no policies, so nothing can be read
-- or written from the app until a story's migration opens exactly what that story needs.

create extension if not exists btree_gist;

create type public.user_role as enum ('owner', 'vet', 'admin');
create type public.vet_status as enum ('pending', 'verified', 'rejected', 'license_expired');
create type public.case_status as enum ('draft', 'submitted', 'closed');
create type public.appointment_status as enum ('booked', 'cancelled', 'completed');
create type public.outcome_status as enum ('draft', 'approved');
create type public.info_request_status as enum ('open', 'answered');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'owner',
  full_name text not null,
  email text not null,
  mobile text,
  terms_accepted_at timestamptz,
  push_enabled boolean not null default true,
  fcm_token text,
  created_at timestamptz not null default now()
);

create table public.vet_profiles (
  id uuid primary key references public.profiles (id) on delete cascade,
  license_number text not null unique,
  license_expiry date not null,
  license_path text not null,
  specialties text[] not null check (cardinality(specialties) > 0),
  animal_types text[] not null check (cardinality(animal_types) > 0),
  languages text[] not null check (cardinality(languages) > 0),
  bio text,
  status public.vet_status not null default 'pending',
  rejection_reason text,
  decided_by uuid references public.profiles (id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.vet_decisions (
  id uuid primary key default gen_random_uuid(),
  vet_id uuid not null references public.vet_profiles (id) on delete cascade,
  admin_id uuid not null references public.profiles (id),
  decision public.vet_status not null,
  reason text,
  decided_at timestamptz not null default now()
);

create table public.animals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  species text not null,
  breed text,
  birth_date date,
  age_years numeric(4, 1) check (age_years >= 0),
  sex text not null check (sex in ('male', 'female')),
  weight_kg numeric(6, 2) check (weight_kg > 0),
  photo_path text,
  conditions text,
  allergies text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint animals_age_known check (birth_date is not null or age_years is not null)
);

create sequence public.case_number_seq;

create table public.cases (
  id uuid primary key default gen_random_uuid(),
  case_number text unique,
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  animal_id uuid not null references public.animals (id) on delete cascade,
  description text,
  voice_path text,
  status public.case_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  submitted_at timestamptz
);

create table public.case_media (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  path text not null,
  kind text not null check (kind in ('photo', 'video')),
  size_bytes bigint not null check (size_bytes <= 30 * 1024 * 1024),
  duration_seconds int check (duration_seconds <= 180),
  created_at timestamptz not null default now()
);

create table public.slots (
  id uuid primary key default gen_random_uuid(),
  vet_id uuid not null references public.vet_profiles (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint slots_thirty_minutes check (ends_at = starts_at + interval '30 minutes'),
  constraint slots_no_overlap exclude using gist (vet_id with =, tstzrange(starts_at, ends_at) with &&)
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid references public.slots (id) on delete set null,
  starts_at timestamptz not null,
  case_id uuid not null references public.cases (id),
  owner_id uuid not null references public.profiles (id),
  vet_id uuid not null references public.vet_profiles (id),
  status public.appointment_status not null default 'booked',
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  rescheduled_at timestamptz,
  reminder_sent_at timestamptz,
  owner_joined_at timestamptz,
  vet_joined_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz
);

-- A slot holds one booking (live or completed); only a cancellation releases it.
create unique index appointments_one_booking_per_slot on public.appointments (slot_id) where status <> 'cancelled';
create index appointments_vet_starts on public.appointments (vet_id, starts_at);
create index appointments_owner_starts on public.appointments (owner_id, starts_at);

create table public.consultation_outcomes (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null unique references public.appointments (id),
  case_id uuid not null references public.cases (id),
  animal_id uuid not null references public.animals (id),
  vet_id uuid not null references public.vet_profiles (id),
  consultation_date date not null,
  findings text not null,
  guidance text not null,
  owner_notes text,
  status public.outcome_status not null default 'draft',
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  vet_id uuid not null references public.vet_profiles (id),
  reason text not null check (length(btrim(reason)) > 0),
  instructions text not null check (length(btrim(instructions)) > 0),
  created_at timestamptz not null default now()
);

create table public.info_requests (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  vet_id uuid not null references public.vet_profiles (id),
  message text not null check (length(btrim(message)) > 0),
  status public.info_request_status not null default 'open',
  response text,
  responded_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  route text,
  read_at timestamptz,
  pushed_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_created on public.notifications (user_id, created_at desc);

create table public.login_attempts (
  email text primary key,
  failures int not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

-- Server-side settings (push webhook URL and secret). No policies: only the database itself reads it.
create table public.app_config (
  key text primary key,
  value text not null
);

alter table public.profiles enable row level security;
alter table public.vet_profiles enable row level security;
alter table public.vet_decisions enable row level security;
alter table public.animals enable row level security;
alter table public.cases enable row level security;
alter table public.case_media enable row level security;
alter table public.slots enable row level security;
alter table public.appointments enable row level security;
alter table public.consultation_outcomes enable row level security;
alter table public.referrals enable row level security;
alter table public.info_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.login_attempts enable row level security;
alter table public.app_config enable row level security;

create function public.my_role() returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() = 'admin', false)
$$;

create function public.is_verified_vet(p_vet uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.vet_profiles
    where id = p_vet and status = 'verified' and license_expiry >= current_date
  )
$$;

create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger animals_touch before update on public.animals
  for each row execute function public.touch_updated_at();
create trigger cases_touch before update on public.cases
  for each row execute function public.touch_updated_at();
create trigger outcomes_touch before update on public.consultation_outcomes
  for each row execute function public.touch_updated_at();
