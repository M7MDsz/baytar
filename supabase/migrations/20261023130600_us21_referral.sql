-- US-21 Refer a Case for In-Person Care. (Owners read referrals through the US-16 policy.)

create policy referrals_vet_select on public.referrals
  for select to authenticated using (public.is_assigned_vet(case_id));

create function public.create_referral(p_case uuid, p_reason text, p_instructions text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_id uuid;
begin
  if not public.is_assigned_vet(p_case) then
    raise exception 'not_assigned';
  end if;
  if btrim(coalesce(p_reason, '')) = '' or btrim(coalesce(p_instructions, '')) = '' then
    raise exception 'reason_and_instructions_required';
  end if;
  insert into public.referrals (case_id, vet_id, reason, instructions)
  values (p_case, auth.uid(), btrim(p_reason), btrim(p_instructions))
  returning id into v_id;
  select owner_id into v_owner from public.cases where id = p_case;
  perform public.notify(v_owner, 'referral', 'إحالة لزيارة عيادة', 'أحالك الطبيب لزيارة عيادة بيطرية. افتح الحالة لقراءة التعليمات.', '/cases/' || p_case);
  return v_id;
end;
$$;
