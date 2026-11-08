-- 제재 목록: 순수 매크로 의심(자동 검사 보류/경고/제외 + 이의 신청)만. 서버검증 이상 단독·운영자 본인은 제외
create or replace function public.gogu_admin_flagged() returns table(
  code text, nickname text, state text, note text, flag_at timestamptz,
  sus int, max_streak int, save_flags int, appeal text, appeal_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.gogu_require_op();
  return query
    select p.code, p.nickname, p.flag_state, p.flag_note, p.flag_at,
           coalesce((select sum(x.sus)::int from public.gogu_touch_stats x where x.user_id = p.id and x.day >= (now() at time zone 'Asia/Seoul')::date - 2), 0),
           coalesce((select max(x.max_streak) from public.gogu_touch_stats x where x.user_id = p.id and x.day >= (now() at time zone 'Asia/Seoul')::date - 2), 0),
           coalesce(s.flags, 0),
           (select a.note from public.gogu_appeals a where a.user_id = p.id and a.status = 'open' limit 1),
           (select a.created_at from public.gogu_appeals a where a.user_id = p.id and a.status = 'open' limit 1)
    from public.gogu_profiles p left join public.gogu_saves s on s.user_id = p.id
    where not p.is_admin
      and (p.flag_state <> 'ok'
           or exists (select 1 from public.gogu_appeals a where a.user_id = p.id and a.status = 'open'))
    order by (p.flag_state = 'hold') desc, p.flag_at desc nulls last
    limit 200;
end $$;

-- 일괄 처리: 줄별 결과(닉네임·처리됨/건너뜀 사유)를 함께 돌려줘요
create or replace function public.gogu_admin_sanction(p_codes text[], p_action text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare cd text; pid uuid; nn text; done int := 0; skipped int := 0; cur int := public.gogu_season(); res jsonb := '[]'::jsonb;
begin
  perform public.gogu_require_op();
  if p_action not in ('hold','release','clear','ban') then raise exception 'bad action'; end if;
  if p_action = 'ban' and not public.gogu_is_admin() then raise exception '영구 제외는 대표 운영자만 할 수 있어요'; end if;
  if coalesce(array_length(p_codes, 1), 0) = 0 or array_length(p_codes, 1) > 200 then raise exception 'bad codes'; end if;
  foreach cd in array p_codes loop
    select id, nickname into pid, nn from public.gogu_profiles where code = upper(btrim(cd));
    if pid is null then
      skipped := skipped + 1; res := res || jsonb_build_object('code', cd, 'nickname', null, 'ok', false, 'why', '없는 계정'); continue;
    end if;
    if pid = auth.uid() then
      skipped := skipped + 1; res := res || jsonb_build_object('code', cd, 'nickname', nn, 'ok', false, 'why', '본인 계정은 처리할 수 없어요'); continue;
    end if;
    if p_action = 'hold' then
      update public.gogu_profiles set flag_state = 'hold', flag_at = now(), flag_note = '운영자: ' || left(coalesce(p_note, '확인 필요'), 100) where id = pid;
    elsif p_action = 'release' then
      update public.gogu_profiles set flag_state = 'warned', warn_season = cur, flag_note = null, flag_at = now() where id = pid;
    elsif p_action = 'clear' then
      update public.gogu_profiles set flag_state = 'ok', flag_note = null, flag_at = null where id = pid;
      update public.gogu_saves set flags = 0 where user_id = pid;
    else
      update public.gogu_profiles set flag_state = 'banned', flag_at = now(), flag_note = '영구 제외' || coalesce(': ' || left(p_note, 100), '') where id = pid;
    end if;
    update public.gogu_appeals set status = 'done', resolved_at = now(), resolved_by = auth.uid()
      where user_id = pid and status = 'open';
    done := done + 1;
    res := res || jsonb_build_object('code', cd, 'nickname', nn, 'ok', true, 'why', null);
  end loop;
  return jsonb_build_object('done', done, 'skipped', skipped, 'results', res);
end $$;
notify pgrst, 'reload schema';
