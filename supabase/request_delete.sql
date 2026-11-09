-- 운영자: 신청 내역 삭제 (체크한 신청을 목록에서 완전히 제거). 이미 지급된 아이템에는 영향 없음
create or replace function public.gogu_admin_requests_delete(p_ids uuid[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r record; done int := 0; res jsonb := '[]'::jsonb; id1 uuid;
begin
  perform public.gogu_require_op();
  if coalesce(array_length(p_ids, 1), 0) = 0 or array_length(p_ids, 1) > 200 then raise exception 'bad ids'; end if;
  foreach id1 in array p_ids loop
    select q.id, p.nickname, i.name as item_name into r
      from public.gogu_requests q join public.gogu_profiles p on p.id = q.user_id join public.gogu_items i on i.id = q.item_id
      where q.id = id1;
    if not found then
      res := res || jsonb_build_object('id', id1, 'nickname', null, 'item', null, 'ok', false, 'why', '이미 없는 신청');
      continue;
    end if;
    delete from public.gogu_requests where id = id1;
    done := done + 1;
    res := res || jsonb_build_object('id', id1, 'nickname', r.nickname, 'item', r.item_name, 'ok', true, 'why', null);
  end loop;
  return jsonb_build_object('done', done, 'results', res);
end $$;
revoke all on function public.gogu_admin_requests_delete(uuid[]) from public, anon;
grant execute on function public.gogu_admin_requests_delete(uuid[]) to authenticated;
notify pgrst, 'reload schema';
