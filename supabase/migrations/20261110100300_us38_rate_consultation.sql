-- US-38 Rate a Consultation.
-- The owner rates a consultation once its outcome is documented: 1 to 5 stars and an optional comment of up to 300
-- characters, once, within 14 days. Cancelled appointments cannot be rated. The veterinarian's profile (US-10) shows
-- the average and the number of ratings, and comments with the owner's first name only. The table is in the Sprint 3
-- shared schema.

-- When the rating window closes: 14 days after the consultation ended (or started, if it was never ended).
create function public.rating_closes_at(a public.appointments) returns timestamptz
language sql immutable as $$
  select coalesce(a.ended_at, a.starts_at) + interval '14 days'
$$;

create function public.rate_consultation(p_appointment uuid, p_stars int, p_comment text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
  v_comment text := nullif(btrim(coalesce(p_comment, '')), '');
  v_id uuid;
begin
  select * into a from public.appointments where id = p_appointment;
  if not found or a.owner_id <> auth.uid() then
    raise exception 'not_your_consultation';
  end if;
  if a.status = 'cancelled' then
    raise exception 'appointment_cancelled';
  end if;
  if not exists (
    select 1 from public.consultation_outcomes where appointment_id = a.id and status = 'approved'
  ) then
    raise exception 'outcome_not_documented';
  end if;
  if now() > public.rating_closes_at(a) then
    raise exception 'rating_closed';
  end if;
  if p_stars is null or p_stars not between 1 and 5 then
    raise exception 'bad_stars';
  end if;
  if char_length(v_comment) > 300 then
    raise exception 'comment_too_long';
  end if;
  if exists (select 1 from public.consultation_ratings where appointment_id = a.id) then
    raise exception 'already_rated';
  end if;
  insert into public.consultation_ratings (appointment_id, owner_id, vet_id, stars, comment)
    values (a.id, a.owner_id, a.vet_id, p_stars, v_comment)
    returning id into v_id;
  return v_id;
end;
$$;

-- The owner's view of rating one consultation:
--   state      'rated' (stars and comment are theirs), 'available' (they can rate it until closes_at),
--              'closed' (the 14 days have passed) or 'unavailable' (cancelled, or the outcome is not documented yet)
-- Only for the appointment's owner; anyone else gets no rows.
create function public.my_consultation_rating(p_appointment uuid)
returns table (state text, stars int, comment text, rated_at timestamptz, closes_at timestamptz)
language sql stable security definer set search_path = public as $$
  select case
           when r.id is not null then 'rated'
           when a.status = 'cancelled'
                or not exists (select 1 from public.consultation_outcomes o
                               where o.appointment_id = a.id and o.status = 'approved') then 'unavailable'
           when now() > public.rating_closes_at(a) then 'closed'
           else 'available'
         end,
         r.stars::int, r.comment, r.created_at, public.rating_closes_at(a)
  from public.appointments a
  left join public.consultation_ratings r on r.appointment_id = a.id
  where a.id = p_appointment and a.owner_id = auth.uid()
$$;

-- US-10, now with the ratings: rating is the average (one decimal, null with no ratings) and rating_count the number.
drop function public.vet_public_profile(uuid);
create function public.vet_public_profile(p_vet uuid)
returns table (
  id uuid,
  full_name text,
  specialties text[],
  animal_types text[],
  languages text[],
  bio text,
  license_number text,
  license_expiry date,
  next_available timestamptz,
  rating numeric,
  gender text,
  rating_count int
)
language sql stable security definer set search_path = public as $$
  select v.id, p.full_name, v.specialties, v.animal_types, v.languages, v.bio,
         v.license_number, v.license_expiry, public.next_free_slot(v.id),
         (select round(avg(r.stars), 1) from public.consultation_ratings r where r.vet_id = v.id),
         v.gender,
         (select count(*)::int from public.consultation_ratings r where r.vet_id = v.id)
  from public.vet_profiles v
  join public.profiles p on p.id = v.id
  where v.id = p_vet and v.status = 'verified' and v.license_expiry >= current_date
$$;

-- The comments on a verified veterinarian's profile, newest first, with only the owner's first name.
create function public.vet_reviews(p_vet uuid, p_limit int default 20)
returns table (stars int, comment text, owner_first_name text, rated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.stars::int, r.comment, split_part(btrim(p.full_name), ' ', 1), r.created_at
  from public.consultation_ratings r
  join public.profiles p on p.id = r.owner_id
  where r.vet_id = p_vet and r.comment is not null and public.is_verified_vet(p_vet)
  order by r.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;
