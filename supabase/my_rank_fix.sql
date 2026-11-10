-- 내 순위/팝업: 아직 기록이 없는 계정(초당 0 · 터치당 1)은 순위를 주지 않아요 (랭킹 목록과 같은 기준)
create or replace function public.gogu_my_rank(p_kind text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); s int := public.gogu_season(); mine numeric; rk bigint; st text; adm boolean;
begin
  if uid is null then return null; end if;
  if p_kind not in ('ps','pc') then raise exception 'bad kind'; end if;
  select flag_state, is_admin into st, adm from public.gogu_profiles where id = uid;
  select case when p_kind = 'pc' then best_pc else best_ps end into mine
    from public.gogu_records where user_id = uid and season = s;
  if mine is null then return null; end if;
  if adm then return jsonb_build_object('hidden', true, 'admin', true, 'value', mine); end if;
  -- 아직 기록이 없는 계정(초당 0 · 터치당 1)은 랭킹 목록과 같은 기준으로 순위를 주지 않아요
  if (case when p_kind = 'pc' then mine <= 1 else mine <= 0 end) then return null; end if;
  if st in ('hold','banned') then return jsonb_build_object('hidden', true, 'value', mine); end if;
  select count(*) + 1 into rk from public.gogu_records r join public.gogu_profiles p on p.id = r.user_id
    where r.season = s and p.flag_state in ('ok','warned') and not p.is_admin
      and (case when p_kind = 'pc' then r.best_pc else r.best_ps end) > mine;
  return jsonb_build_object('rank', rk, 'value', mine);
end $$;
notify pgrst, 'reload schema';
