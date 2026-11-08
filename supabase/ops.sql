-- ============================================================
-- 고구마 굽기 운영 기능 추가 (schema.sql 을 먼저 실행한 뒤, 이 파일을 한 번 실행)
--  * 터치 패턴 검사 + 제재(안내→경고 1회→영구 제외) + 이의 신청
--  * 운영자 여러 명 + 지급 한도 + 지급 기록
--  * 아이템 신청 / 일괄 승인, 아이템 기간제(만료일)
--  * 무료 룰렛, 친구(최대 50명), 프로필 공개 설정
--  여러 번 실행해도 안전합니다.
-- ============================================================

-- ---------- 스킨 아이템 등록 (skins.sql 내용 포함: 따로 실행하지 않아도 됩니다) ----------
-- 분류: tier = 유료(paid) / 이벤트(event), slot = 고구마(potato) / 화로(brazier) / 불(fire)
-- 무료 스킨은 서버 등록 없이 누구나 사용합니다.
insert into public.gogu_items(id,name,kind,descr,tier,slot) values
 ('skin_p_chestnut','밤고구마','skin','고구마 외형','paid','potato'),
 ('skin_p_violet','자색고구마','skin','고구마 외형','paid','potato'),
 ('skin_p_gold','황금고구마','skin','고구마 외형','paid','potato'),
 ('skin_p_snow','눈꽃고구마','skin','고구마 외형','event','potato'),
 ('skin_p_ember','불타는 고구마','skin','고구마 외형','event','potato'),
 ('skin_p_rainbow','무지개고구마','skin','고구마 외형','event','potato'),
 ('skin_b_gold','황금 화로','skin','화로 외형','paid','brazier'),
 ('skin_b_rose','로즈골드 화로','skin','화로 외형','paid','brazier'),
 ('skin_b_ruby','루비 화로','skin','화로 외형','paid','brazier'),
 ('skin_b_sapphire','사파이어 화로','skin','화로 외형','paid','brazier'),
 ('skin_b_amethyst','자수정 화로','skin','화로 외형','paid','brazier'),
 ('skin_b_obsidian','흑요석 화로','skin','화로 외형','event','brazier'),
 ('skin_b_ice','얼음 화로','skin','화로 외형','event','brazier'),
 ('skin_b_jade','비취 화로','skin','화로 외형','event','brazier'),
 ('skin_f_purple','보라 불꽃','skin','불 외형','paid','fire'),
 ('skin_f_pink','분홍 불꽃','skin','불 외형','paid','fire'),
 ('skin_f_white','백색 불꽃','skin','불 외형','paid','fire'),
 ('skin_f_gold','황금 불꽃','skin','불 외형','paid','fire'),
 ('skin_f_teal','청록 불꽃','skin','불 외형','paid','fire'),
 ('skin_f_green','초록 불꽃','skin','불 외형','event','fire'),
 ('skin_f_crimson','진홍 불꽃','skin','불 외형','event','fire'),
 ('skin_f_rainbow','무지개 불꽃','skin','불 외형','event','fire')
on conflict (id) do update set name=excluded.name, kind=excluded.kind, descr=excluded.descr, tier=excluded.tier, slot=excluded.slot;

-- 예전 임시 스킨 3개 정리 (아무도 갖고 있지 않을 때만 삭제)
delete from public.gogu_items i
 where i.id in ('skin_brazier_gold','skin_potato_purple','skin_fire_blue')
   and not exists(select 1 from public.gogu_user_items u where u.item_id=i.id)
   and not exists(select 1 from public.gogu_gifts g where g.item_id=i.id);

-- ---------- 컬럼 추가 ----------
alter table public.gogu_profiles
  add column if not exists is_op boolean not null default false,
  add column if not exists flag_state text not null default 'ok',
  add column if not exists flag_note text,
  add column if not exists flag_at timestamptz,
  add column if not exists warn_season int,
  add column if not exists last_spin date,
  add column if not exists show_profile boolean not null default true;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'gogu_profiles_flag_state_chk') then
    alter table public.gogu_profiles add constraint gogu_profiles_flag_state_chk
      check (flag_state in ('ok','hold','warned','banned'));
  end if;
end $$;

alter table public.gogu_user_items add column if not exists expires_at timestamptz;
alter table public.gogu_gifts add column if not exists item_days int;

-- ---------- 새 테이블 ----------
create table if not exists public.gogu_touch_stats(
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  windows int not null default 0,
  sus int not null default 0,
  streak int not null default 0,
  max_streak int not null default 0,
  last_at timestamptz,
  primary key(user_id, day)
);

create table if not exists public.gogu_appeals(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note text not null,
  status text not null default 'open' check (status in ('open','done')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid
);
create unique index if not exists gogu_appeals_open on public.gogu_appeals(user_id) where status = 'open';

create table if not exists public.gogu_requests(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.gogu_items(id),
  note text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid
);
create unique index if not exists gogu_requests_pending on public.gogu_requests(user_id, item_id) where status = 'pending';

create table if not exists public.gogu_roulette_prizes(
  id serial primary key,
  label text not null,
  kind text not null check (kind in ('points','coupon','event_skin')),
  amount int,
  item_days int,
  weight int not null check (weight > 0)
);

create table if not exists public.gogu_friends(
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  check (from_user <> to_user)
);
create unique index if not exists gogu_friends_pair on public.gogu_friends(least(from_user, to_user), greatest(from_user, to_user));
create index if not exists gogu_friends_to on public.gogu_friends(to_user);

-- 룰렛 상품표 (확률 = weight / 전체 합). 바꾸려면 이 표만 고치면 됩니다.
insert into public.gogu_roulette_prizes(label, kind, amount, item_days, weight)
select * from (values
  ('포인트 5',   'points',     5,    null::int, 200),
  ('포인트 10',  'points',     10,   null, 250),
  ('포인트 30',  'points',     30,   null, 200),
  ('포인트 100', 'points',     100,  null, 90),
  ('화력 최대 쿠폰 1장', 'coupon', 1, null, 150),
  ('화력 최대 쿠폰 3장', 'coupon', 3, null, 60),
  ('이벤트 스킨 (7일, 무작위)',  'event_skin', null, 7,  45),
  ('이벤트 스킨 (30일, 무작위)', 'event_skin', null, 30, 5)
) v(label, kind, amount, item_days, weight)
where not exists (select 1 from public.gogu_roulette_prizes);

do $$
declare t text;
begin
  foreach t in array array['gogu_touch_stats','gogu_appeals','gogu_requests','gogu_roulette_prizes','gogu_friends'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- ---------- 권한 확인 ----------
create or replace function public.gogu_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.gogu_profiles where id = auth.uid()), false);
$$;

create or replace function public.gogu_require_op() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or not coalesce((select is_admin or is_op from public.gogu_profiles where id = auth.uid()), false) then
    raise exception 'forbidden';
  end if;
end $$;

create or replace function public.gogu_free_skins() returns text[]
language sql immutable as $$
  select array['skin_p_default','skin_p_pumpkin','skin_b_default','skin_b_silver','skin_b_copper','skin_f_default','skin_f_blue'];
$$;

-- 유효한(만료되지 않은) 보유 아이템
create or replace function public.gogu_has_item(p_user uuid, p_item text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.gogu_user_items
                 where user_id = p_user and item_id = p_item and (expires_at is null or expires_at > now()));
$$;

-- ---------- 칭호: 만료 확인 ----------
create or replace function public.gogu_set_title(p_item text) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  if p_item is null or p_item = '' then
    update public.gogu_profiles set title = null where id = uid; return;
  end if;
  if not exists (select 1 from public.gogu_user_items ui join public.gogu_items i on i.id = ui.item_id
                 where ui.user_id = uid and ui.item_id = p_item and i.kind = 'title'
                   and (ui.expires_at is null or ui.expires_at > now())) then
    raise exception '보유하지 않은 칭호예요';
  end if;
  update public.gogu_profiles set title = (select name from public.gogu_items where id = p_item) where id = uid;
end $$;

-- ---------- 불러오기 (제재 상태, 만료일, 친구 요청 수 포함) ----------
create or replace function public.gogu_load() returns jsonb
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; s public.gogu_saves; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  p := public.gogu_ensure_profile();
  -- 만료된 칭호는 자동으로 내림
  if p.title is not null and not exists (
      select 1 from public.gogu_user_items ui join public.gogu_items i on i.id = ui.item_id
      where ui.user_id = uid and i.kind = 'title' and i.name = p.title and (ui.expires_at is null or ui.expires_at > now())) then
    update public.gogu_profiles set title = null where id = uid;
    p.title := null;
  end if;
  select * into s from public.gogu_saves where user_id = uid;
  return jsonb_build_object(
    'season', public.gogu_season(),
    'profile', jsonb_build_object('code', p.code, 'nickname', p.nickname, 'title', p.title,
                                   'is_admin', p.is_admin, 'is_op', p.is_op, 'clan_id', p.clan_id,
                                   'nickname_changed_at', p.nickname_changed_at,
                                   'flag_state', p.flag_state, 'show_profile', p.show_profile,
                                   'recur', coalesce(p.flag_note like '재발%', false)),
    'save', case when s.user_id is null then null else s.data end,
    'save_season', case when s.user_id is null then null else s.season end,
    'save_at', case when s.user_id is null then null else s.updated_at end,
    'items', coalesce((select jsonb_agg(item_id) from public.gogu_user_items
                       where user_id = uid and (expires_at is null or expires_at > now())), '[]'::jsonb),
    'items_exp', coalesce((select jsonb_object_agg(item_id, expires_at) from public.gogu_user_items
                           where user_id = uid and expires_at is not null and expires_at > now()), '{}'::jsonb),
    'gifts', (select count(*) from public.gogu_gifts g
              where g.to_user = uid and g.claimed_at is null and (g.expires_at is null or g.expires_at > now())),
    'friend_in', (select count(*) from public.gogu_friends f where f.to_user = uid and f.status = 'pending'),
    'appeal_open', exists (select 1 from public.gogu_appeals a where a.user_id = uid and a.status = 'open'),
    'spun_today', coalesce(p.last_spin = (now() at time zone 'Asia/Seoul')::date, false)
  );
end $$;

-- ---------- 선물함 (기간제 표시) / 받기 (만료일 적용) ----------
drop function if exists public.gogu_gifts_list();
create function public.gogu_gifts_list() returns table(
  id uuid, kind text, item_id text, item_name text, amount int, note text, created_at timestamptz,
  expires_at timestamptz, item_days int)
language sql stable security definer set search_path = public as $$
  select g.id, g.kind, g.item_id, i.name, g.amount, g.note, g.created_at, g.expires_at, g.item_days
  from public.gogu_gifts g left join public.gogu_items i on i.id = g.item_id
  where g.to_user = auth.uid() and g.claimed_at is null and (g.expires_at is null or g.expires_at > now())
  order by g.created_at desc limit 50;
$$;

create or replace function public.gogu_gift_claim(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); g public.gogu_gifts; exp timestamptz;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into g from public.gogu_gifts where id = p_id and to_user = uid for update;
  if not found then raise exception '선물을 찾을 수 없어요'; end if;
  if g.claimed_at is not null then raise exception '이미 받은 선물이에요'; end if;
  if g.expires_at is not null and g.expires_at <= now() then raise exception '기간이 지난 선물이에요'; end if;
  update public.gogu_gifts set claimed_at = now() where id = g.id;
  if g.kind = 'item' then
    exp := case when g.item_days is null then null else now() + make_interval(days => g.item_days) end;
    insert into public.gogu_user_items(user_id, item_id, source, expires_at) values (uid, g.item_id, 'gift', exp)
    on conflict (user_id, item_id) do update set expires_at = case
        when public.gogu_user_items.expires_at is null then null          -- 이미 영구 보유
        when excluded.expires_at is null then null                         -- 영구로 승급
        when public.gogu_user_items.expires_at > now() then public.gogu_user_items.expires_at + make_interval(days => g.item_days)
        else excluded.expires_at end;
  end if;
  return jsonb_build_object('kind', g.kind, 'item_id', g.item_id, 'amount', g.amount, 'item_days', g.item_days);
end $$;

-- ---------- 랭킹: 보류·영구 제외 계정은 순위에서 뺌 ----------
create or replace function public.gogu_ranking(p_kind text, p_new boolean default false,
                                               p_season int default null, p_limit int default 50)
returns table(rank bigint, nickname text, title text, clan text, value numeric)
language plpgsql stable security definer set search_path = public as $$
declare s int := coalesce(p_season, public.gogu_season());
begin
  if p_kind not in ('ps','pc') then raise exception 'bad kind'; end if;
  return query
    select row_number() over (order by v.val desc, v.ts asc), v.nickname, v.title, v.clan, v.val
    from (
      select p.nickname, p.title, c.name as clan, r.updated_at as ts,
             case when p_kind = 'pc' then r.best_pc else r.best_ps end as val
      from public.gogu_records r
      join public.gogu_profiles p on p.id = r.user_id
      left join public.gogu_clans c on c.id = p.clan_id
      where r.season = s
        and p.flag_state in ('ok','warned')
        and (not coalesce(p_new, false) or p.created_at > now() - interval '7 days')
        and (case when p_kind = 'pc' then r.best_pc > 1 else r.best_ps > 0 end)
    ) v
    order by 1
    limit greatest(1, least(coalesce(p_limit, 50), 100));
end $$;

create or replace function public.gogu_my_rank(p_kind text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); s int := public.gogu_season(); mine numeric; rk bigint; st text;
begin
  if uid is null then return null; end if;
  if p_kind not in ('ps','pc') then raise exception 'bad kind'; end if;
  select flag_state into st from public.gogu_profiles where id = uid;
  select case when p_kind = 'pc' then best_pc else best_ps end into mine
    from public.gogu_records where user_id = uid and season = s;
  if mine is null then return null; end if;
  if st in ('hold','banned') then return jsonb_build_object('hidden', true, 'value', mine); end if;
  select count(*) + 1 into rk from public.gogu_records r join public.gogu_profiles p on p.id = r.user_id
    where r.season = s and p.flag_state in ('ok','warned')
      and (case when p_kind = 'pc' then r.best_pc else r.best_ps end) > mine;
  return jsonb_build_object('rank', rk, 'value', mine);
end $$;

create or replace function public.gogu_clan_ranking(p_limit int default 30)
returns table(rank bigint, clan text, members bigint, score numeric)
language sql stable security definer set search_path = public as $$
  with m as (
    select p.clan_id, r.best_ps,
           row_number() over (partition by p.clan_id order by r.best_ps desc) as rn
    from public.gogu_profiles p
    join public.gogu_records r on r.user_id = p.id and r.season = public.gogu_season()
    where p.clan_id is not null and r.best_ps > 0 and p.flag_state in ('ok','warned')
  )
  select row_number() over (order by sum(m.best_ps) desc), c.name,
         (select count(*) from public.gogu_profiles x where x.clan_id = c.id),
         sum(m.best_ps)
  from m join public.gogu_clans c on c.id = m.clan_id
  where m.rn <= 10
  group by c.id, c.name
  order by 1
  limit greatest(1, least(coalesce(p_limit, 30), 100));
$$;

-- ============================================================
--  터치 패턴 검사
--   클라이언트가 30초마다 (터치 횟수, 간격의 변동계수)를 보냅니다.
--   - 규칙적 구간: 30초에 100번 이상 + 간격이 기계처럼 일정(변동계수 < 0.08)
--   - 하루 규칙적 구간 40번(약 20분) 이상, 또는 쉬지 않고 6시간 연속 터치 → 보류(안내)
--  ※ 앱 안에서 100% 구분할 수는 없어요. 걸러내는 장치이고 확정은 운영자가 합니다.
-- ============================================================
create or replace function public.gogu_report_touch(p_n int, p_cv numeric) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); d date := (now() at time zone 'Asia/Seoul')::date;
  t public.gogu_touch_stats; p public.gogu_profiles; cur int := public.gogu_season();
  is_sus boolean; new_streak int; new_sus int; reason text := null;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where id = uid;
  if not found then return null; end if;
  if p_n is null or p_n < 0 or p_n > 3000 or p_cv is null or p_cv < 0 or p_cv > 100 then raise exception 'bad stats'; end if;
  insert into public.gogu_touch_stats(user_id, day) values (uid, d) on conflict do nothing;
  select * into t from public.gogu_touch_stats where user_id = uid and day = d for update;
  if t.last_at is not null and now() - t.last_at < interval '20 seconds' then
    return jsonb_build_object('state', p.flag_state);
  end if;
  if p_n < 30 then
    update public.gogu_touch_stats set streak = 0, last_at = now() where user_id = uid and day = d;
    return jsonb_build_object('state', p.flag_state);
  end if;
  is_sus := p_n >= 100 and p_cv < 0.08;
  new_streak := case when t.last_at is not null and now() - t.last_at <= interval '90 seconds' and t.streak > 0
                     then t.streak + 1 else 1 end;
  new_sus := t.sus + case when is_sus then 1 else 0 end;
  update public.gogu_touch_stats
     set windows = windows + 1, sus = new_sus, streak = new_streak,
         max_streak = greatest(max_streak, new_streak), last_at = now()
   where user_id = uid and day = d;
  if new_sus >= 40 then reason := '규칙적인 터치 ' || new_sus || '구간(30초 단위)';
  elsif new_streak >= 720 then reason := '6시간 이상 쉬지 않고 터치'; end if;
  if reason is not null and (p.flag_state = 'ok' or (p.flag_state = 'warned' and coalesce(p.warn_season, -1) <> cur)) then
    update public.gogu_profiles set flag_state = 'hold', flag_at = now(), flag_note = '자동: ' || reason where id = uid;
    return jsonb_build_object('state', 'hold', 'new', true);
  elsif reason is not null and p.flag_state = 'warned' then
    update public.gogu_profiles set flag_state = 'hold', flag_at = now(), flag_note = '재발: ' || reason where id = uid;
    return jsonb_build_object('state', 'hold', 'new', true, 'recur', true);
  end if;
  return jsonb_build_object('state', p.flag_state);
end $$;

-- 이의 신청 (보류 상태에서만, 1건)
create or replace function public.gogu_appeal_submit(p_note text) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); st text;
begin
  if uid is null then raise exception 'login required'; end if;
  select flag_state into st from public.gogu_profiles where id = uid;
  if st is distinct from 'hold' then raise exception '이의 신청이 필요한 상태가 아니에요'; end if;
  p_note := btrim(coalesce(p_note, ''));
  if char_length(p_note) < 5 or char_length(p_note) > 300 then raise exception '사유를 5~300자로 적어 주세요'; end if;
  begin
    insert into public.gogu_appeals(user_id, note) values (uid, p_note);
  exception when unique_violation then
    raise exception '이미 접수된 이의 신청이 있어요. 운영자가 확인 중이에요';
  end;
end $$;

-- 운영자: 의심·제재·이의 신청 목록
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
    where p.flag_state <> 'ok' or coalesce(s.flags, 0) >= 3
       or exists (select 1 from public.gogu_appeals a where a.user_id = p.id and a.status = 'open')
    order by (p.flag_state = 'hold') desc, p.flag_at desc nulls last
    limit 200;
end $$;

-- 운영자: 일괄 처리. hold=보류, release=해명 인정(경고 1회 후 해제), clear=오탐(경고 없이 해제), ban=영구 제외(대표만)
create or replace function public.gogu_admin_sanction(p_codes text[], p_action text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare cd text; pid uuid; done int := 0; skipped int := 0; cur int := public.gogu_season();
begin
  perform public.gogu_require_op();
  if p_action not in ('hold','release','clear','ban') then raise exception 'bad action'; end if;
  if p_action = 'ban' and not public.gogu_is_admin() then raise exception '영구 제외는 대표 운영자만 할 수 있어요'; end if;
  if coalesce(array_length(p_codes, 1), 0) = 0 or array_length(p_codes, 1) > 200 then raise exception 'bad codes'; end if;
  foreach cd in array p_codes loop
    select id into pid from public.gogu_profiles where code = upper(btrim(cd)) and id <> auth.uid();
    if pid is null then skipped := skipped + 1; continue; end if;
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
  end loop;
  return jsonb_build_object('done', done, 'skipped', skipped);
end $$;

-- ============================================================
--  운영자 여러 명 / 지급 한도 / 지급 기록
-- ============================================================
create or replace function public.gogu_admin_set_op(p_code text, p_on boolean) returns text
language plpgsql security definer set search_path = public as $$
declare n text;
begin
  if not public.gogu_is_admin() then raise exception 'forbidden'; end if;
  update public.gogu_profiles set is_op = coalesce(p_on, false)
    where code = upper(btrim(coalesce(p_code, ''))) and is_admin = false returning nickname into n;
  if n is null then raise exception '없는 코드이거나 대표 운영자예요'; end if;
  return n;
end $$;

create or replace function public.gogu_admin_ops() returns table(code text, nickname text, is_admin boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.gogu_require_op();
  return query select p.code, p.nickname, p.is_admin from public.gogu_profiles p
    where p.is_admin or p.is_op order by p.is_admin desc, p.nickname;
end $$;

create or replace function public.gogu_admin_lookup(p_code text) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.gogu_require_op();
  return (select nickname from public.gogu_profiles where code = upper(btrim(coalesce(p_code, ''))));
end $$;

-- 지급: 대표는 제한 없음, 일반 운영자는 유료 스킨 불가 / 포인트 1000·쿠폰 10 이하 / 하루 30명 / 본인 제외
drop function if exists public.gogu_admin_give(text[], text, text, int, text, int);
create or replace function public.gogu_admin_give(p_codes text[], p_kind text, p_item text, p_amount int,
                                                  p_note text, p_days int default 30, p_item_days int default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare cd text; uid uuid; given int := 0; missing text[] := '{}'; adm boolean; me uuid := auth.uid(); today_cnt int; tier text;
begin
  perform public.gogu_require_op();
  adm := public.gogu_is_admin();
  if p_kind not in ('item','points','coupon') then raise exception 'bad kind'; end if;
  if p_kind = 'item' then
    select i.tier into tier from public.gogu_items i where i.id = p_item;
    if not found then raise exception 'bad item'; end if;
    if not adm and tier = 'paid' then raise exception '유료 스킨은 대표 운영자만 지급할 수 있어요'; end if;
  end if;
  if p_kind <> 'item' and (p_amount is null or p_amount < 1 or p_amount > 100000) then raise exception 'bad amount'; end if;
  if not adm and ((p_kind = 'points' and p_amount > 1000) or (p_kind = 'coupon' and p_amount > 10)) then
    raise exception '운영자 지급 한도를 넘었어요 (포인트 1000, 쿠폰 10장)';
  end if;
  if p_item_days is not null and (p_item_days < 1 or p_item_days > 3650) then raise exception 'bad days'; end if;
  if coalesce(array_length(p_codes, 1), 0) = 0 or array_length(p_codes, 1) > 200 then raise exception 'bad codes'; end if;
  if not adm then
    select count(*) into today_cnt from public.gogu_gifts
      where from_admin = me and created_at >= ((now() at time zone 'Asia/Seoul')::date)::timestamp at time zone 'Asia/Seoul';
    if today_cnt + array_length(p_codes, 1) > 30 then raise exception '하루 지급 한도(30명)를 넘어요. 오늘 % 명 지급함', today_cnt; end if;
  end if;
  foreach cd in array p_codes loop
    cd := upper(btrim(cd));
    select id into uid from public.gogu_profiles where code = cd;
    if uid is null then missing := missing || cd; continue; end if;
    if uid = me and not adm then raise exception '본인에게는 지급할 수 없어요'; end if;
    insert into public.gogu_gifts(to_user, kind, item_id, amount, note, from_admin, expires_at, item_days)
    values (uid, p_kind, case when p_kind = 'item' then p_item end,
            case when p_kind <> 'item' then p_amount end,
            left(coalesce(p_note, ''), 100), me,
            case when p_days is null or p_days < 1 then null else now() + make_interval(days => p_days) end,
            case when p_kind = 'item' then p_item_days end);
    given := given + 1;
  end loop;
  return jsonb_build_object('given', given, 'missing', to_jsonb(missing));
end $$;

-- 지급 기록 (대표 운영자)
create or replace function public.gogu_admin_log(p_limit int default 100)
returns table(at timestamptz, by_nick text, to_nick text, kind text, item text, amount int, item_days int, claimed boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.gogu_is_admin() then raise exception 'forbidden'; end if;
  return query
    select g.created_at, a.nickname, t.nickname, g.kind, i.name, g.amount, g.item_days, g.claimed_at is not null
    from public.gogu_gifts g
    left join public.gogu_profiles a on a.id = g.from_admin
    left join public.gogu_profiles t on t.id = g.to_user
    left join public.gogu_items i on i.id = g.item_id
    where g.from_admin is not null
    order by g.created_at desc limit greatest(1, least(coalesce(p_limit, 100), 300));
end $$;

-- ============================================================
--  아이템 신청 → 운영자 일괄 승인
-- ============================================================
create or replace function public.gogu_request_create(p_item text, p_note text) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); it public.gogu_items; st text;
begin
  if uid is null then raise exception 'login required'; end if;
  select flag_state into st from public.gogu_profiles where id = uid;
  if st is null then raise exception 'no profile'; end if;
  if st = 'banned' then raise exception '신청할 수 없는 계정이에요'; end if;
  select * into it from public.gogu_items where id = p_item;
  if not found then raise exception '없는 아이템이에요'; end if;
  if public.gogu_has_item(uid, p_item) then raise exception '이미 보유 중이에요'; end if;
  if (select count(*) from public.gogu_requests where user_id = uid and status = 'pending') >= 5 then
    raise exception '대기 중인 신청이 너무 많아요 (최대 5개)';
  end if;
  if (select count(*) from public.gogu_requests where user_id = uid and created_at > now() - interval '24 hours') >= 5 then
    raise exception '하루에 5번까지 신청할 수 있어요';
  end if;
  begin
    insert into public.gogu_requests(user_id, item_id, note) values (uid, p_item, left(btrim(coalesce(p_note, '')), 100));
  exception when unique_violation then
    raise exception '이미 신청한 아이템이에요';
  end;
end $$;

create or replace function public.gogu_request_my() returns table(item_id text, item_name text, status text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.item_id, i.name, r.status, r.created_at from public.gogu_requests r
  join public.gogu_items i on i.id = r.item_id
  where r.user_id = auth.uid() and r.created_at > now() - interval '30 days'
  order by r.created_at desc limit 30;
$$;

create or replace function public.gogu_admin_requests() returns table(
  id uuid, code text, nickname text, item_id text, item_name text, tier text, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.gogu_require_op();
  return query
    select r.id, p.code, p.nickname, r.item_id, i.name, i.tier, r.note, r.created_at
    from public.gogu_requests r join public.gogu_profiles p on p.id = r.user_id join public.gogu_items i on i.id = r.item_id
    where r.status = 'pending' order by r.created_at limit 300;
end $$;

create or replace function public.gogu_admin_requests_resolve(p_ids uuid[], p_approve boolean, p_item_days int default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r record; done int := 0; skipped int := 0; adm boolean; me uuid := auth.uid(); today_cnt int;
begin
  perform public.gogu_require_op();
  adm := public.gogu_is_admin();
  if coalesce(array_length(p_ids, 1), 0) = 0 or array_length(p_ids, 1) > 200 then raise exception 'bad ids'; end if;
  if p_item_days is not null and (p_item_days < 1 or p_item_days > 3650) then raise exception 'bad days'; end if;
  for r in select q.id, q.user_id, q.item_id, i.tier from public.gogu_requests q join public.gogu_items i on i.id = q.item_id
           where q.id = any(p_ids) and q.status = 'pending' for update of q loop
    if p_approve then
      if r.user_id = me and not adm then skipped := skipped + 1; continue; end if;
      if not adm then
        if r.tier = 'paid' then skipped := skipped + 1; continue; end if;
        select count(*) into today_cnt from public.gogu_gifts
          where from_admin = me and created_at >= ((now() at time zone 'Asia/Seoul')::date)::timestamp at time zone 'Asia/Seoul';
        if today_cnt >= 30 then skipped := skipped + 1; continue; end if;
      end if;
      insert into public.gogu_gifts(to_user, kind, item_id, note, from_admin, expires_at, item_days)
      values (r.user_id, 'item', r.item_id, '신청 승인', me, now() + interval '30 days', p_item_days);
      update public.gogu_requests set status = 'approved', resolved_at = now(), resolved_by = me where id = r.id;
    else
      update public.gogu_requests set status = 'rejected', resolved_at = now(), resolved_by = me where id = r.id;
    end if;
    done := done + 1;
  end loop;
  return jsonb_build_object('done', done, 'skipped', skipped);
end $$;

-- ============================================================
--  무료 룰렛 (하루 1번, 한국 시간 기준)
-- ============================================================
create or replace function public.gogu_roulette_odds() returns table(label text, pct numeric)
language sql stable security definer set search_path = public as $$
  select label, round(weight * 100.0 / sum(weight) over (), 1) from public.gogu_roulette_prizes order by weight desc, id;
$$;

create or replace function public.gogu_roulette_spin() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); p public.gogu_profiles; today date := (now() at time zone 'Asia/Seoul')::date;
  total int; roll int; acc int := 0; pr public.gogu_roulette_prizes; skin public.gogu_items; gid uuid;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where id = uid for update;
  if not found then raise exception 'no profile'; end if;
  if p.flag_state = 'banned' then raise exception '이용할 수 없는 계정이에요'; end if;
  if p.last_spin = today then raise exception '오늘은 이미 돌렸어요. 내일 또 도전하세요!'; end if;
  select sum(weight) into total from public.gogu_roulette_prizes;
  roll := 1 + floor(random() * total)::int;
  for pr in select * from public.gogu_roulette_prizes order by id loop
    acc := acc + pr.weight;
    if roll <= acc then exit; end if;
  end loop;
  if pr.kind = 'event_skin' then
    select * into skin from public.gogu_items where kind = 'skin' and tier = 'event' order by random() limit 1;
    if not found then
      pr.kind := 'points'; pr.amount := 30; pr.label := '포인트 30';
    end if;
  end if;
  update public.gogu_profiles set last_spin = today where id = uid;
  insert into public.gogu_gifts(to_user, kind, item_id, amount, note, expires_at, item_days)
  values (uid, case when pr.kind = 'event_skin' then 'item' else pr.kind end,
          case when pr.kind = 'event_skin' then skin.id end,
          case when pr.kind <> 'event_skin' then pr.amount end,
          '룰렛 당첨', now() + interval '7 days', case when pr.kind = 'event_skin' then pr.item_days end)
  returning id into gid;
  return jsonb_build_object('gift_id', gid, 'label', case when pr.kind = 'event_skin' then skin.name || ' (' || pr.item_days || '일)' else pr.label end,
                            'kind', pr.kind);
end $$;

-- ============================================================
--  친구 (최대 50명)
-- ============================================================
create or replace function public.gogu_friend_count(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.gogu_friends where status = 'accepted' and (from_user = p_user or to_user = p_user);
$$;

create or replace function public.gogu_friend_request(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); t public.gogu_profiles; f public.gogu_friends; st text;
begin
  if me is null then raise exception 'login required'; end if;
  select flag_state into st from public.gogu_profiles where id = me;
  if st is null then raise exception 'no profile'; end if;
  if st = 'banned' then raise exception '이용할 수 없는 계정이에요'; end if;
  select * into t from public.gogu_profiles where code = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception '없는 코드예요'; end if;
  if t.id = me then raise exception '내 코드예요'; end if;
  select * into f from public.gogu_friends
    where least(from_user, to_user) = least(me, t.id) and greatest(from_user, to_user) = greatest(me, t.id);
  if found then
    if f.status = 'accepted' then raise exception '이미 친구예요'; end if;
    if f.from_user = me then raise exception '이미 친구 신청을 보냈어요'; end if;
    -- 상대가 먼저 보낸 신청이 있으면 바로 수락
    if public.gogu_friend_count(me) >= 50 then raise exception '친구가 가득 찼어요 (최대 50명)'; end if;
    if public.gogu_friend_count(t.id) >= 50 then raise exception '상대 친구가 가득 찼어요'; end if;
    update public.gogu_friends set status = 'accepted', accepted_at = now() where id = f.id;
    return t.nickname;
  end if;
  if public.gogu_friend_count(me) >= 50 then raise exception '친구가 가득 찼어요 (최대 50명)'; end if;
  if public.gogu_friend_count(t.id) >= 50 then raise exception '상대 친구가 가득 찼어요'; end if;
  if (select count(*) from public.gogu_friends where from_user = me and status = 'pending') >= 20 then
    raise exception '보낸 신청이 너무 많아요 (최대 20개)';
  end if;
  if (select count(*) from public.gogu_friends where from_user = me and created_at > now() - interval '24 hours') >= 20 then
    raise exception '하루에 20명까지 신청할 수 있어요';
  end if;
  insert into public.gogu_friends(from_user, to_user) values (me, t.id);
  return t.nickname;
end $$;

create or replace function public.gogu_friend_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); s int := public.gogu_season();
begin
  if me is null then return null; end if;
  return jsonb_build_object(
    'friends', coalesce((
      select jsonb_agg(jsonb_build_object('id', f.id, 'nickname', p.nickname, 'title', p.title,
               'ps', case when p.flag_state in ('hold','banned') or not p.show_profile then null else coalesce(r.best_ps, 0) end,
               'pc', case when p.flag_state in ('hold','banned') or not p.show_profile then null else coalesce(r.best_pc, 1) end)
             order by case when p.flag_state in ('hold','banned') or not p.show_profile then 0 else coalesce(r.best_ps, 0) end desc, p.nickname)
      from public.gogu_friends f
      join public.gogu_profiles p on p.id = case when f.from_user = me then f.to_user else f.from_user end
      left join public.gogu_records r on r.user_id = p.id and r.season = s
      where f.status = 'accepted' and (f.from_user = me or f.to_user = me)), '[]'::jsonb),
    'incoming', coalesce((
      select jsonb_agg(jsonb_build_object('id', f.id, 'nickname', p.nickname) order by f.created_at)
      from public.gogu_friends f join public.gogu_profiles p on p.id = f.from_user
      where f.status = 'pending' and f.to_user = me), '[]'::jsonb),
    'outgoing', coalesce((
      select jsonb_agg(jsonb_build_object('id', f.id, 'nickname', p.nickname) order by f.created_at)
      from public.gogu_friends f join public.gogu_profiles p on p.id = f.to_user
      where f.status = 'pending' and f.from_user = me), '[]'::jsonb),
    'max', 50
  );
end $$;

create or replace function public.gogu_friend_respond(p_id uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); f public.gogu_friends;
begin
  if me is null then raise exception 'login required'; end if;
  select * into f from public.gogu_friends where id = p_id and to_user = me and status = 'pending' for update;
  if not found then raise exception '신청을 찾을 수 없어요'; end if;
  if coalesce(p_accept, false) then
    if public.gogu_friend_count(me) >= 50 then raise exception '친구가 가득 찼어요 (최대 50명)'; end if;
    if public.gogu_friend_count(f.from_user) >= 50 then raise exception '상대 친구가 가득 찼어요'; end if;
    update public.gogu_friends set status = 'accepted', accepted_at = now() where id = f.id;
  else
    delete from public.gogu_friends where id = f.id;
  end if;
end $$;

create or replace function public.gogu_friend_remove(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  delete from public.gogu_friends where id = p_id and (from_user = auth.uid() or to_user = auth.uid());
end $$;

-- 친구 프로필: 친구끼리만. 상대가 공개를 꺼 두면 닉네임만 보임
create or replace function public.gogu_friend_profile(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); f public.gogu_friends; fid uuid; p public.gogu_profiles; r public.gogu_records;
        sv jsonb; sk jsonb := '{}'::jsonb; k text; v text; s int := public.gogu_season(); clan text;
begin
  if me is null then raise exception 'login required'; end if;
  select * into f from public.gogu_friends where id = p_id and status = 'accepted' and (from_user = me or to_user = me);
  if not found then raise exception '친구가 아니에요'; end if;
  fid := case when f.from_user = me then f.to_user else f.from_user end;
  select * into p from public.gogu_profiles where id = fid;
  if not p.show_profile then return jsonb_build_object('nickname', p.nickname, 'hidden', true); end if;
  select * into r from public.gogu_records where user_id = fid and season = s;
  select data->'skin' into sv from public.gogu_saves where user_id = fid;
  if sv is not null and jsonb_typeof(sv) = 'object' then
    foreach k in array array['p','b','f'] loop
      v := sv->>k;
      if v is not null and (v = any(public.gogu_free_skins()) or public.gogu_has_item(fid, v)) then
        sk := sk || jsonb_build_object(k, v);
      end if;
    end loop;
  end if;
  select name into clan from public.gogu_clans where id = p.clan_id;
  return jsonb_build_object('nickname', p.nickname, 'title', p.title, 'clan', clan, 'skin', sk,
    'ps', case when p.flag_state in ('hold','banned') then null else coalesce(r.best_ps, 0) end,
    'pc', case when p.flag_state in ('hold','banned') then null else coalesce(r.best_pc, 1) end,
    'joined', p.created_at);
end $$;

create or replace function public.gogu_set_show_profile(p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  update public.gogu_profiles set show_profile = coalesce(p_on, true) where id = auth.uid();
end $$;

-- ---------- 실행 권한 ----------
do $$
declare f text;
begin
  foreach f in array array[
    'gogu_is_admin()','gogu_require_op()','gogu_free_skins()','gogu_has_item(uuid,text)','gogu_friend_count(uuid)',
    'gogu_set_title(text)','gogu_load()','gogu_gifts_list()','gogu_gift_claim(uuid)','gogu_my_rank(text)',
    'gogu_report_touch(int,numeric)','gogu_appeal_submit(text)','gogu_admin_flagged()','gogu_admin_sanction(text[],text,text)',
    'gogu_admin_set_op(text,boolean)','gogu_admin_ops()','gogu_admin_lookup(text)',
    'gogu_admin_give(text[],text,text,int,text,int,int)','gogu_admin_log(int)',
    'gogu_request_create(text,text)','gogu_request_my()','gogu_admin_requests()','gogu_admin_requests_resolve(uuid[],boolean,int)',
    'gogu_roulette_odds()','gogu_roulette_spin()',
    'gogu_friend_request(text)','gogu_friend_list()','gogu_friend_respond(uuid,boolean)','gogu_friend_remove(uuid)',
    'gogu_friend_profile(uuid)','gogu_set_show_profile(boolean)',
    'gogu_ranking(text,boolean,int,int)','gogu_clan_ranking(int)'
  ] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  -- 내부 도우미는 직접 부르지 못하게 둠 (다른 함수 안에서만 사용)
  foreach f in array array[
    'gogu_set_title(text)','gogu_load()','gogu_gifts_list()','gogu_gift_claim(uuid)','gogu_my_rank(text)',
    'gogu_report_touch(int,numeric)','gogu_appeal_submit(text)','gogu_admin_flagged()','gogu_admin_sanction(text[],text,text)',
    'gogu_admin_set_op(text,boolean)','gogu_admin_ops()','gogu_admin_lookup(text)',
    'gogu_admin_give(text[],text,text,int,text,int,int)','gogu_admin_log(int)',
    'gogu_request_create(text,text)','gogu_request_my()','gogu_admin_requests()','gogu_admin_requests_resolve(uuid[],boolean,int)',
    'gogu_roulette_spin()',
    'gogu_friend_request(text)','gogu_friend_list()','gogu_friend_respond(uuid,boolean)','gogu_friend_remove(uuid)',
    'gogu_friend_profile(uuid)','gogu_set_show_profile(boolean)'
  ] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['gogu_ranking(text,boolean,int,int)','gogu_clan_ranking(int)','gogu_roulette_odds()'] loop
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end $$;
