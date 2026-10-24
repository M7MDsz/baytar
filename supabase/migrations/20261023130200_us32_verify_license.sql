-- US-32 Verify a Veterinarian's License.
-- Administrators review pending registrations (oldest first) and approve or reject with a reason.
-- Every decision is logged with the administrator and time; a daily job expires out-of-date licenses.

create policy vet_profiles_admin_select on public.vet_profiles
  for select to authenticated using (public.is_admin());

create policy profiles_admin_select on public.profiles
  for select to authenticated using (public.is_admin());

create policy vet_decisions_admin_select on public.vet_decisions
  for select to authenticated using (public.is_admin());

create policy licenses_admin_read on storage.objects
  for select to authenticated using (bucket_id = 'licenses' and public.is_admin());

create function public.pending_vets()
returns table (
  id uuid,
  full_name text,
  email text,
  mobile text,
  license_number text,
  license_expiry date,
  license_path text,
  specialties text[],
  animal_types text[],
  languages text[],
  bio text,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden';
  end if;
  return query
    select v.id, p.full_name, p.email, p.mobile, v.license_number, v.license_expiry, v.license_path,
           v.specialties, v.animal_types, v.languages, v.bio, v.created_at
    from public.vet_profiles v
    join public.profiles p on p.id = v.id
    where v.status = 'pending'
    order by v.created_at asc;
end;
$$;

create function public.decide_vet(p_vet uuid, p_approve boolean, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_status public.vet_status := case when p_approve then 'verified' else 'rejected' end;
begin
  if not public.is_admin() then
    raise exception 'forbidden';
  end if;
  if not p_approve and v_reason is null then
    raise exception 'reason_required';
  end if;
  update public.vet_profiles
    set status = v_status,
        rejection_reason = case when p_approve then null else v_reason end,
        decided_by = auth.uid(),
        decided_at = now()
    where id = p_vet and status = 'pending';
  if not found then
    raise exception 'not_pending';
  end if;
  insert into public.vet_decisions (vet_id, admin_id, decision, reason) values (p_vet, auth.uid(), v_status, v_reason);
  if p_approve then
    perform public.notify(p_vet, 'verification', 'تم توثيق حسابك', 'يمكنك الآن نشر مواعيدك واستقبال الاستشارات.', '/vet/profile');
  else
    perform public.notify(p_vet, 'verification', 'لم يتم قبول طلب التسجيل', 'سبب الرفض: ' || v_reason, '/vet/profile');
  end if;
end;
$$;

create function public.expire_licenses() returns int
language plpgsql security definer set search_path = public as $$
declare
  v record;
  n int := 0;
begin
  for v in
    update public.vet_profiles set status = 'license_expired'
    where status = 'verified' and license_expiry < current_date
    returning id
  loop
    perform public.notify(v.id, 'verification', 'انتهى ترخيصك', 'حدّث ترخيصك لتظهر للملاك مرة أخرى.', '/vet/profile');
    n := n + 1;
  end loop;
  return n;
end;
$$;

revoke execute on function public.expire_licenses() from public, anon, authenticated;

select cron.schedule('expire-vet-licenses', '5 0 * * *', 'select public.expire_licenses()');
