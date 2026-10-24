-- US-18 Request Additional Case Information.

create policy info_requests_owner_select on public.info_requests
  for select to authenticated
  using (exists (select 1 from public.cases c where c.id = case_id and c.owner_id = auth.uid()));

create policy info_requests_vet_select on public.info_requests
  for select to authenticated using (vet_id = auth.uid() and public.is_assigned_vet(case_id));

create function public.request_info(p_case uuid, p_message text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
  v_id uuid;
begin
  if not public.is_assigned_vet(p_case) then
    raise exception 'not_assigned';
  end if;
  if btrim(coalesce(p_message, '')) = '' then
    raise exception 'message_required';
  end if;
  insert into public.info_requests (case_id, vet_id, message)
  values (p_case, auth.uid(), btrim(p_message))
  returning id into v_id;
  select owner_id into v_owner from public.cases where id = p_case;
  -- The request text is shown in the app; the push itself stays generic (push-dispatch).
  perform public.notify(v_owner, 'info_request', 'طلب معلومات من الطبيب', btrim(p_message), '/requests/' || v_id);
  return v_id;
end;
$$;

create function public.answer_info(p_request uuid, p_response text) returns void
language plpgsql security definer set search_path = public as $$
declare
  r public.info_requests;
begin
  select ir.* into r
  from public.info_requests ir join public.cases c on c.id = ir.case_id
  where ir.id = p_request and c.owner_id = auth.uid()
  for update of ir;
  if not found then
    raise exception 'request_not_found';
  end if;
  if r.status <> 'open' then
    raise exception 'already_answered';
  end if;
  if btrim(coalesce(p_response, '')) = '' then
    raise exception 'response_required';
  end if;
  update public.info_requests
    set response = btrim(p_response), responded_at = now(), status = 'answered'
    where id = p_request;
  perform public.notify(r.vet_id, 'info_answer', 'رد على طلب معلومات', 'رد المالك على طلبك.', '/vet/cases/' || r.case_id);
end;
$$;
