-- 시즌 종료 보상: 초당·터치당 각각 상위 3명
--  · 칭호(영구, 시즌마다 쌓임): "시즌N 초당 1위" 처럼 시즌별 칭호를 새로 만들어 지급
--  · 선물(30일): 오프라인 적립 24시간 + 쿠폰 보관 +5, 1위는 황금 스킨(초당=황금 화로, 터치당=황금고구마) 30일 추가
--  · 매크로 의심·제외 계정(ok/warned 가 아닌 계정)과 대표 운영자 계정은 제외
--  · 같은 시즌은 한 번만 지급(두 번 눌러도 중복 지급 안 됨)
-- 대표 운영자만 실행 가능. p_commit=false 면 미리보기만 하고 아무것도 바꾸지 않음.
create or replace function public.gogu_admin_season_reward(p_season int, p_commit boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  cur int := public.gogu_season(); k text; r record; out jsonb := '[]'::jsonb;
  tid text; tname text; kname text; done_key text := 'season_reward_' || p_season;
  gift_item text; n int := 0;
begin
  if not public.gogu_is_admin() then raise exception 'forbidden'; end if;
  if p_season is null or p_season < 0 then raise exception 'bad season'; end if;
  if p_commit then
    if p_season >= cur then raise exception '아직 끝나지 않은 시즌이에요 (지금은 시즌 % )', cur; end if;
    if exists (select 1 from public.gogu_settings where key = done_key) then
      raise exception '시즌 % 보상은 이미 지급했어요', p_season;
    end if;
  end if;

  foreach k in array array['ps','pc'] loop
    kname := case when k = 'ps' then '초당' else '터치당' end;
    for r in
      select x.user_id, x.nickname, x.val, x.rn from (
        select rec.user_id, p.nickname,
               case when k = 'ps' then rec.best_ps else rec.best_pc end as val,
               row_number() over (order by case when k = 'ps' then rec.best_ps else rec.best_pc end desc, rec.updated_at asc) as rn
        from public.gogu_records rec
        join public.gogu_profiles p on p.id = rec.user_id
        where rec.season = p_season and p.flag_state in ('ok','warned') and not p.is_admin
          and (case when k = 'pc' then rec.best_pc > 1 else rec.best_ps > 0 end)
      ) x where x.rn <= 3 order by x.rn
    loop
      out := out || jsonb_build_object('kind', kname, 'rank', r.rn, 'nickname', r.nickname, 'value', r.val);
      if p_commit then
        tid := 'title_s' || p_season || '_' || k || r.rn;
        tname := '시즌' || p_season || ' ' || kname || ' ' || r.rn || '위';
        insert into public.gogu_items(id, name, kind, descr)
          values (tid, tname, 'title', '시즌 ' || p_season || ' ' || kname || ' ' || r.rn || '위 기념 칭호')
          on conflict (id) do nothing;
        insert into public.gogu_user_items(user_id, item_id, source) values (r.user_id, tid, 'season')
          on conflict (user_id, item_id) do nothing;
        foreach gift_item in array array['perk_offline24','perk_coupon15'] ||
            case when r.rn = 1 then array[case when k = 'ps' then 'skin_b_gold' else 'skin_p_gold' end] else array[]::text[] end
        loop
          insert into public.gogu_gifts(to_user, kind, item_id, note, from_admin, expires_at, item_days)
          values (r.user_id, 'item', gift_item, left('시즌 ' || p_season || ' ' || kname || ' ' || r.rn || '위 보상', 100),
                  auth.uid(), now() + interval '60 days', 30);
          n := n + 1;
        end loop;
      end if;
    end loop;
  end loop;

  if p_commit then
    insert into public.gogu_settings(key, value) values (done_key, now()::text);
  end if;
  return jsonb_build_object('season', p_season, 'committed', p_commit, 'winners', out, 'gifts', n);
end $$;

revoke all on function public.gogu_admin_season_reward(int, boolean) from public, anon;
grant execute on function public.gogu_admin_season_reward(int, boolean) to authenticated;
notify pgrst, 'reload schema';
