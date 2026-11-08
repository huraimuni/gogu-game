-- 오픈 전 안전장치: 저장 이전본 보관 / 대표 복구 / 회원 탈퇴
create table if not exists public.gogu_save_history(
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  season int not null,
  data jsonb not null,
  saved_at timestamptz not null default now(),
  primary key(user_id, day)
);
alter table public.gogu_save_history enable row level security;
revoke all on public.gogu_save_history from anon, authenticated;

create or replace function public.gogu_save(p_data jsonb, p_born timestamptz) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); cur_season int := public.gogu_season();
  o public.gogu_saves; c record; oc record;
  old_spent numeric := 0; old_t timestamptz; dt numeric; allowed numeric; ok boolean; had_old boolean;
begin
  if uid is null then raise exception 'login required'; end if;
  if not exists (select 1 from public.gogu_profiles where id = uid) then raise exception 'no profile'; end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' or octet_length(p_data::text) > 30000 then
    raise exception 'bad data';
  end if;

  select * into c from public.gogu_calc(p_data->'lv');
  select * into o from public.gogu_saves where user_id = uid;
  had_old := found;

  if found and o.season = cur_season then
    select * into oc from public.gogu_calc(o.data->'lv');
    old_spent := oc.spent; old_t := o.updated_at;
  else
    old_t := greatest(coalesce(p_born, now()), now() - interval '14 days');
  end if;
  dt := greatest(extract(epoch from (now() - old_t)), 5);
  -- 부스트 7배와 초당 50번 터치까지 넉넉히 인정한 상한
  allowed := old_spent + dt * 7 * (c.ps + 50 * c.pc) + 200;
  ok := c.spent <= allowed;

  -- 하루에 한 번, 덮어쓰기 직전의 저장본을 남겨요 (최근 7일). 사고가 나면 대표 운영자가 되돌릴 수 있어요.
  if had_old then
    insert into public.gogu_save_history(user_id, day, season, data)
      values (uid, (now() at time zone 'Asia/Seoul')::date, o.season, o.data)
      on conflict (user_id, day) do nothing;
    delete from public.gogu_save_history where user_id = uid and day < (now() at time zone 'Asia/Seoul')::date - 7;
  end if;

  insert into public.gogu_saves(user_id, season, data, flags, updated_at)
  values (uid, cur_season, p_data, case when ok then 0 else 1 end, now())
  on conflict (user_id) do update
    set season = excluded.season, data = excluded.data, updated_at = now(),
        flags = public.gogu_saves.flags + case when ok then 0 else 1 end;

  if ok then
    insert into public.gogu_records(user_id, season, best_ps, best_pc, updated_at)
    values (uid, cur_season, c.ps, c.pc, now())
    on conflict (user_id, season) do update
      set best_ps = greatest(public.gogu_records.best_ps, excluded.best_ps),
          best_pc = greatest(public.gogu_records.best_pc, excluded.best_pc),
          updated_at = now();
  end if;
  return jsonb_build_object('ok', true, 'plausible', ok, 'season', cur_season);
end $$;

-- 대표 운영자: 코드로 유저를 찾아 날짜 목록 보기(p_day 없음) 또는 그 날짜 저장본으로 되돌리기
create or replace function public.gogu_admin_restore_save(p_code text, p_day date default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid; h public.gogu_save_history; days jsonb;
begin
  if not public.gogu_is_admin() then raise exception 'forbidden'; end if;
  select id into uid from public.gogu_profiles where code = upper(btrim(p_code));
  if uid is null then raise exception '코드를 찾을 수 없어요'; end if;
  if p_day is null then
    select coalesce(jsonb_agg(day order by day desc), '[]'::jsonb) into days from public.gogu_save_history where user_id = uid;
    return jsonb_build_object('days', days);
  end if;
  select * into h from public.gogu_save_history where user_id = uid and day = p_day;
  if not found then raise exception '그 날짜의 저장본이 없어요'; end if;
  update public.gogu_saves set data = h.data, season = h.season, updated_at = now() where user_id = uid;
  return jsonb_build_object('restored', p_day);
end $$;

-- 회원 탈퇴: 계정과 모든 기록·아이템 삭제 (되돌릴 수 없음). 대표 계정은 막아 둠.
create or replace function public.gogu_delete_account() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  if exists (select 1 from public.gogu_profiles where id = uid and (is_admin or is_op)) then
    raise exception '운영자 계정은 탈퇴할 수 없어요. 운영자 해제 후 다시 시도해 주세요';
  end if;
  perform public.gogu_clan_leave();
  delete from auth.users where id = uid;
end $$;

revoke all on function public.gogu_save(jsonb, timestamptz) from public, anon;
grant execute on function public.gogu_save(jsonb, timestamptz) to authenticated;
revoke all on function public.gogu_admin_restore_save(text, date) from public, anon;
grant execute on function public.gogu_admin_restore_save(text, date) to authenticated;
revoke all on function public.gogu_delete_account() from public, anon;
grant execute on function public.gogu_delete_account() to authenticated;
notify pgrst, 'reload schema';
