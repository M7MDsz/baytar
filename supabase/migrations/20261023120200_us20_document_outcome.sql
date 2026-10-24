-- US-20 Document a Consultation Outcome.
-- Only the appointment's own veterinarian can save or approve; an approved outcome is final.

create policy outcomes_vet_select on public.consultation_outcomes
  for select to authenticated using (vet_id = auth.uid());

create function public.save_outcome(
  p_appointment uuid,
  p_findings text,
  p_guidance text,
  p_owner_notes text,
  p_approve boolean
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  a public.appointments;
  c public.cases;
  v_status public.outcome_status := case when p_approve then 'approved' else 'draft' end;
  v_id uuid;
begin
  select * into a from public.appointments where id = p_appointment;
  if not found or a.vet_id <> auth.uid() then
    raise exception 'not_responsible_vet';
  end if;
  if a.started_at is null then
    raise exception 'consultation_not_started';
  end if;
  if p_approve and (btrim(coalesce(p_findings, '')) = '' or btrim(coalesce(p_guidance, '')) = '') then
    raise exception 'findings_and_guidance_required';
  end if;
  if exists (select 1 from public.consultation_outcomes where appointment_id = p_appointment and status = 'approved') then
    raise exception 'already_approved';
  end if;

  select * into c from public.cases where id = a.case_id;
  insert into public.consultation_outcomes
    (appointment_id, case_id, animal_id, vet_id, consultation_date, findings, guidance, owner_notes, status, approved_at)
  values
    (a.id, a.case_id, c.animal_id, a.vet_id, (a.starts_at at time zone 'Asia/Riyadh')::date,
     coalesce(p_findings, ''), coalesce(p_guidance, ''), nullif(btrim(coalesce(p_owner_notes, '')), ''), v_status,
     case when p_approve then now() end)
  on conflict (appointment_id) do update
    set findings = excluded.findings,
        guidance = excluded.guidance,
        owner_notes = excluded.owner_notes,
        status = excluded.status,
        approved_at = excluded.approved_at
  returning id into v_id;

  if p_approve then
    perform public.notify(a.owner_id, 'outcome', 'نتيجة الاستشارة جاهزة', 'اعتمد الطبيب نتيجة استشارتك.', '/outcomes/' || a.id);
  end if;
  return v_id;
end;
$$;
