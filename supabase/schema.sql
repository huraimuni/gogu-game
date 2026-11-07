-- ============================================================
-- 고구마 굽기 서버 구성 (Supabase SQL Editor에서 한 번 실행)
--  * 다른 앱과 섞이지 않도록 모든 이름 앞에 gogu_ 를 붙였습니다.
--  * 테이블은 직접 읽고 쓸 수 없고, 아래 함수(RPC)로만 접근합니다.
--  * 여러 번 실행해도 안전합니다.
-- ============================================================

-- ---------- 테이블 ----------
create table if not exists public.gogu_clans(
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  code text not null unique,
  owner uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.gogu_profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  code text not null unique,
  nickname text not null unique,
  nickname_changed_at timestamptz,
  title text,
  is_admin boolean not null default false,
  clan_id uuid references public.gogu_clans(id) on delete set null,
  clan_changed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.gogu_saves(
  user_id uuid primary key references auth.users(id) on delete cascade,
  season int not null,
  data jsonb not null,
  flags int not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.gogu_records(
  user_id uuid not null references auth.users(id) on delete cascade,
  season int not null,
  best_ps numeric not null default 0,
  best_pc numeric not null default 1,
  updated_at timestamptz not null default now(),
  primary key(user_id, season)
);

create table if not exists public.gogu_items(
  id text primary key,
  name text not null,
  kind text not null check (kind in ('skin','perk','title')),
  descr text
);

create table if not exists public.gogu_user_items(
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.gogu_items(id),
  source text,
  acquired_at timestamptz not null default now(),
  primary key(user_id, item_id)
);

create table if not exists public.gogu_gifts(
  id uuid primary key default gen_random_uuid(),
  to_user uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('item','points','coupon')),
  item_id text references public.gogu_items(id),
  amount int,
  note text,
  from_admin uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  claimed_at timestamptz
);
create index if not exists gogu_gifts_to_idx on public.gogu_gifts(to_user) where claimed_at is null;

-- 업그레이드 정의 (게임의 UP 목록과 같아야 합니다)
create table if not exists public.gogu_up_defs(
  id text primary key,
  kind text not null check (kind in ('c','s')),
  base numeric not null,
  gain numeric not null
);
insert into public.gogu_up_defs(id,kind,base,gain) values
 ('c1','c',15,1),('c2','c',120,6),('c3','c',1400,45),('c4','c',18000,380),('c5','c',240000,3200),
 ('s1','s',40,1),('s2','s',500,8),('s3','s',6000,65),('s4','s',80000,520),
 ('s5','s',1100000,4200),('s6','s',14000000,36000),('s7','s',220000000,310000)
on conflict (id) do update set kind=excluded.kind, base=excluded.base, gain=excluded.gain;

-- 아이템 목록 (외형은 그림이 준비되면 효과가 붙습니다)
-- 스킨 분류: tier = 무료(free) / 유료(paid) / 이벤트(event), slot = 고구마(potato) / 화로(brazier) / 불(fire)
alter table public.gogu_items add column if not exists tier text check (tier in ('free','paid','event'));
alter table public.gogu_items add column if not exists slot text check (slot in ('potato','brazier','fire'));

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
 ('skin_f_rainbow','무지개 불꽃','skin','불 외형','event','fire'),
 ('perk_offline12','오프라인 적립 12시간','perk','자리를 비워도 최대 12시간까지 적립',null,null),
 ('perk_offline24','오프라인 적립 24시간','perk','자리를 비워도 최대 24시간까지 적립',null,null),
 ('perk_coupon15','쿠폰 보관 +5','perk','화력 최대 쿠폰을 최대 15장까지 보관',null,null),
 ('title_pioneer','개척자','title','랭킹 이름 옆에 붙는 칭호',null,null)
on conflict (id) do update set name=excluded.name, kind=excluded.kind, descr=excluded.descr, tier=excluded.tier, slot=excluded.slot;

-- 모든 테이블: 직접 접근 차단 (RLS 켜고 정책 없음 + 권한 회수)
do $$
declare t text;
begin
  foreach t in array array['gogu_clans','gogu_profiles','gogu_saves','gogu_records','gogu_items','gogu_user_items','gogu_gifts','gogu_up_defs'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- ---------- 도우미 ----------
create or replace function public.gogu_rand_code(len int) returns text
language plpgsql volatile as $$
declare a constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; r text := ''; i int;
begin
  for i in 1..len loop r := r || substr(a, 1 + floor(random()*32)::int, 1); end loop;
  return r;
end $$;

-- 시즌 번호: 2026-12-01 전은 0(프리시즌), 이후 3개월마다 1,2,3...
create or replace function public.gogu_season() returns int
language sql stable as $$
  select case
    when (now() at time zone 'Asia/Seoul') < timestamp '2026-12-01' then 0
    else 1 + ((extract(year from now() at time zone 'Asia/Seoul')::int - 2026) * 12
              + extract(month from now() at time zone 'Asia/Seoul')::int - 12) / 3
  end $$;

-- 레벨로 초당/터치당/누적 구매비용 계산 (화력 최대·상점 보너스는 뺀 값)
create or replace function public.gogu_calc(lv jsonb, out ps numeric, out pc numeric, out spent numeric)
language plpgsql stable set search_path = public as $$
declare r record; l numeric;
begin
  ps := 0; pc := 1; spent := 0;
  if lv is null or jsonb_typeof(lv) <> 'object' then return; end if;
  for r in select * from public.gogu_up_defs loop
    l := coalesce((lv->>r.id)::numeric, 0);
    if l < 0 or l > 400 or l <> floor(l) then raise exception 'bad level'; end if;
    if r.kind = 's' then ps := ps + r.gain * l; else pc := pc + r.gain * l; end if;
    spent := spent + r.base * (power(1.15::numeric, l) - 1) / 0.15;
  end loop;
end $$;

create or replace function public.gogu_require_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or not coalesce((select is_admin from public.gogu_profiles where id = auth.uid()), false) then
    raise exception 'forbidden';
  end if;
end $$;

-- ---------- 프로필 ----------
create or replace function public.gogu_ensure_profile() returns public.gogu_profiles
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; c text; n text; tries int := 0; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where id = uid;
  if found then return p; end if;
  loop
    c := 'GOGU-' || public.gogu_rand_code(4) || '-' || public.gogu_rand_code(4);
    exit when not exists (select 1 from public.gogu_profiles where code = c);
  end loop;
  loop
    n := '구움이' || lpad(floor(random()*10000)::int::text, 4, '0');
    exit when not exists (select 1 from public.gogu_profiles where nickname = n);
    tries := tries + 1;
    if tries > 50 then n := '구움이' || public.gogu_rand_code(6); exit; end if;
  end loop;
  insert into public.gogu_profiles(id, code, nickname) values (uid, c, n) on conflict (id) do nothing;
  select * into p from public.gogu_profiles where id = uid;
  return p;
end $$;

create or replace function public.gogu_set_nickname(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  p_name := btrim(coalesce(p_name, ''));
  if p_name !~ '^[가-힣A-Za-z0-9_]{2,10}$' then raise exception '닉네임은 한글·영문·숫자 2~10자예요'; end if;
  select * into p from public.gogu_profiles where id = uid;
  if not found then raise exception 'no profile'; end if;
  if p.nickname = p_name then return p.nickname; end if;
  if p.nickname_changed_at is not null and now() - p.nickname_changed_at < interval '30 days' then
    raise exception '닉네임은 30일에 한 번만 바꿀 수 있어요';
  end if;
  begin
    update public.gogu_profiles set nickname = p_name, nickname_changed_at = now() where id = uid;
  exception when unique_violation then
    raise exception '이미 사용 중인 닉네임이에요';
  end;
  return p_name;
end $$;

create or replace function public.gogu_set_title(p_item text) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  if p_item is null or p_item = '' then
    update public.gogu_profiles set title = null where id = uid; return;
  end if;
  if not exists (select 1 from public.gogu_user_items ui join public.gogu_items i on i.id = ui.item_id
                 where ui.user_id = uid and ui.item_id = p_item and i.kind = 'title') then
    raise exception '보유하지 않은 칭호예요';
  end if;
  update public.gogu_profiles set title = (select name from public.gogu_items where id = p_item) where id = uid;
end $$;

-- ---------- 불러오기 / 저장 ----------
create or replace function public.gogu_load() returns jsonb
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; s public.gogu_saves; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  p := public.gogu_ensure_profile();
  select * into s from public.gogu_saves where user_id = uid;
  return jsonb_build_object(
    'season', public.gogu_season(),
    'profile', jsonb_build_object('code', p.code, 'nickname', p.nickname, 'title', p.title,
                                   'is_admin', p.is_admin, 'clan_id', p.clan_id,
                                   'nickname_changed_at', p.nickname_changed_at),
    'save', case when s.user_id is null then null else s.data end,
    'save_season', case when s.user_id is null then null else s.season end,
    'save_at', case when s.user_id is null then null else s.updated_at end,
    'items', coalesce((select jsonb_agg(item_id) from public.gogu_user_items where user_id = uid), '[]'::jsonb),
    'gifts', (select count(*) from public.gogu_gifts g
              where g.to_user = uid and g.claimed_at is null and (g.expires_at is null or g.expires_at > now()))
  );
end $$;

-- p_born: 이번 시즌 진행을 시작한 시각(클라이언트 기준). 서버에 저장이 없을 때만 최대 14일까지 인정
create or replace function public.gogu_save(p_data jsonb, p_born timestamptz) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); cur_season int := public.gogu_season();
  o public.gogu_saves; c record; oc record;
  old_spent numeric := 0; old_t timestamptz; dt numeric; allowed numeric; ok boolean;
begin
  if uid is null then raise exception 'login required'; end if;
  if not exists (select 1 from public.gogu_profiles where id = uid) then raise exception 'no profile'; end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' or octet_length(p_data::text) > 30000 then
    raise exception 'bad data';
  end if;

  select * into c from public.gogu_calc(p_data->'lv');
  select * into o from public.gogu_saves where user_id = uid;

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

-- ---------- 랭킹 ----------
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
        and (not coalesce(p_new, false) or p.created_at > now() - interval '7 days')
        and (case when p_kind = 'pc' then r.best_pc > 1 else r.best_ps > 0 end)
    ) v
    order by 1
    limit greatest(1, least(coalesce(p_limit, 50), 100));
end $$;

create or replace function public.gogu_my_rank(p_kind text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); s int := public.gogu_season(); mine numeric; rk bigint;
begin
  if uid is null then return null; end if;
  if p_kind not in ('ps','pc') then raise exception 'bad kind'; end if;
  select case when p_kind = 'pc' then best_pc else best_ps end into mine
    from public.gogu_records where user_id = uid and season = s;
  if mine is null then return null; end if;
  select count(*) + 1 into rk from public.gogu_records
    where season = s and (case when p_kind = 'pc' then best_pc else best_ps end) > mine;
  return jsonb_build_object('rank', rk, 'value', mine);
end $$;

-- 클랜 순위: 클랜원 중 이번 시즌 초당 상위 10명 합계
create or replace function public.gogu_clan_ranking(p_limit int default 30)
returns table(rank bigint, clan text, members bigint, score numeric)
language sql stable security definer set search_path = public as $$
  with m as (
    select p.clan_id, r.best_ps,
           row_number() over (partition by p.clan_id order by r.best_ps desc) as rn
    from public.gogu_profiles p
    join public.gogu_records r on r.user_id = p.id and r.season = public.gogu_season()
    where p.clan_id is not null and r.best_ps > 0
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

-- ---------- 클랜 ----------
create or replace function public.gogu_clan_my() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.gogu_profiles; c public.gogu_clans;
begin
  if uid is null then return null; end if;
  select * into p from public.gogu_profiles where id = uid;
  if not found or p.clan_id is null then return null; end if;
  select * into c from public.gogu_clans where id = p.clan_id;
  return jsonb_build_object(
    'name', c.name, 'code', c.code, 'is_owner', c.owner = uid,
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('nickname', x.nickname, 'ps', coalesce(r.best_ps, 0), 'owner', x.id = c.owner)
                       order by coalesce(r.best_ps, 0) desc)
      from public.gogu_profiles x
      left join public.gogu_records r on r.user_id = x.id and r.season = public.gogu_season()
      where x.clan_id = c.id), '[]'::jsonb)
  );
end $$;

create or replace function public.gogu_clan_create(p_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.gogu_profiles; cid uuid; cc text;
begin
  if uid is null then raise exception 'login required'; end if;
  p_name := btrim(coalesce(p_name, ''));
  if p_name !~ '^[가-힣A-Za-z0-9_ ]{2,12}$' then raise exception '클랜 이름은 한글·영문·숫자 2~12자예요'; end if;
  select * into p from public.gogu_profiles where id = uid for update;
  if not found then raise exception 'no profile'; end if;
  if p.clan_id is not null then raise exception '이미 클랜에 가입되어 있어요'; end if;
  if p.clan_changed_at is not null and now() - p.clan_changed_at < interval '7 days' then
    raise exception '클랜은 7일에 한 번만 바꿀 수 있어요';
  end if;
  loop
    cc := 'CL-' || public.gogu_rand_code(6);
    exit when not exists (select 1 from public.gogu_clans where code = cc);
  end loop;
  begin
    insert into public.gogu_clans(name, code, owner) values (p_name, cc, uid) returning id into cid;
  exception when unique_violation then
    raise exception '이미 있는 클랜 이름이에요';
  end;
  update public.gogu_profiles set clan_id = cid, clan_changed_at = now() where id = uid;
  return public.gogu_clan_my();
end $$;

create or replace function public.gogu_clan_join(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.gogu_profiles; c public.gogu_clans;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where id = uid for update;
  if not found then raise exception 'no profile'; end if;
  if p.clan_id is not null then raise exception '이미 클랜에 가입되어 있어요'; end if;
  if p.clan_changed_at is not null and now() - p.clan_changed_at < interval '7 days' then
    raise exception '클랜은 7일에 한 번만 바꿀 수 있어요';
  end if;
  select * into c from public.gogu_clans where code = upper(btrim(coalesce(p_code, ''))) for update;
  if not found then raise exception '없는 클랜 코드예요'; end if;
  if (select count(*) from public.gogu_profiles where clan_id = c.id) >= 30 then
    raise exception '클랜 인원이 가득 찼어요 (최대 30명)';
  end if;
  update public.gogu_profiles set clan_id = c.id, clan_changed_at = now() where id = uid;
  return public.gogu_clan_my();
end $$;

create or replace function public.gogu_clan_leave() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.gogu_profiles; c public.gogu_clans; nxt uuid;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where id = uid for update;
  if not found or p.clan_id is null then return; end if;
  select * into c from public.gogu_clans where id = p.clan_id for update;
  update public.gogu_profiles set clan_id = null, clan_changed_at = now() where id = uid;
  if c.owner = uid then
    select id into nxt from public.gogu_profiles where clan_id = c.id order by created_at limit 1;
    if nxt is null then delete from public.gogu_clans where id = c.id;
    else update public.gogu_clans set owner = nxt where id = c.id; end if;
  end if;
end $$;

-- ---------- 선물함 ----------
create or replace function public.gogu_gifts_list() returns table(
  id uuid, kind text, item_id text, item_name text, amount int, note text, created_at timestamptz, expires_at timestamptz)
language sql stable security definer set search_path = public as $$
  select g.id, g.kind, g.item_id, i.name, g.amount, g.note, g.created_at, g.expires_at
  from public.gogu_gifts g left join public.gogu_items i on i.id = g.item_id
  where g.to_user = auth.uid() and g.claimed_at is null and (g.expires_at is null or g.expires_at > now())
  order by g.created_at desc limit 50;
$$;

create or replace function public.gogu_gift_claim(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); g public.gogu_gifts;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into g from public.gogu_gifts where id = p_id and to_user = uid for update;
  if not found then raise exception '선물을 찾을 수 없어요'; end if;
  if g.claimed_at is not null then raise exception '이미 받은 선물이에요'; end if;
  if g.expires_at is not null and g.expires_at <= now() then raise exception '기간이 지난 선물이에요'; end if;
  update public.gogu_gifts set claimed_at = now() where id = g.id;
  if g.kind = 'item' then
    insert into public.gogu_user_items(user_id, item_id, source) values (uid, g.item_id, 'gift')
    on conflict do nothing;
  end if;
  return jsonb_build_object('kind', g.kind, 'item_id', g.item_id, 'amount', g.amount);
end $$;

-- ---------- 운영자 ----------
create or replace function public.gogu_admin_lookup(p_code text) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.gogu_require_admin();
  return (select nickname from public.gogu_profiles where code = upper(btrim(coalesce(p_code, ''))));
end $$;

create or replace function public.gogu_admin_give(p_codes text[], p_kind text, p_item text,
                                                  p_amount int, p_note text, p_days int default 30) returns jsonb
language plpgsql security definer set search_path = public as $$
declare cd text; uid uuid; given int := 0; missing text[] := '{}';
begin
  perform public.gogu_require_admin();
  if p_kind not in ('item','points','coupon') then raise exception 'bad kind'; end if;
  if p_kind = 'item' and not exists (select 1 from public.gogu_items where id = p_item) then raise exception 'bad item'; end if;
  if p_kind <> 'item' and (p_amount is null or p_amount < 1 or p_amount > 100000) then raise exception 'bad amount'; end if;
  if coalesce(array_length(p_codes, 1), 0) = 0 or array_length(p_codes, 1) > 200 then raise exception 'bad codes'; end if;
  foreach cd in array p_codes loop
    cd := upper(btrim(cd));
    select id into uid from public.gogu_profiles where code = cd;
    if uid is null then missing := missing || cd; continue; end if;
    insert into public.gogu_gifts(to_user, kind, item_id, amount, note, from_admin, expires_at)
    values (uid, p_kind, case when p_kind = 'item' then p_item end,
            case when p_kind <> 'item' then p_amount end,
            left(coalesce(p_note, ''), 100), auth.uid(),
            case when p_days is null or p_days < 1 then null else now() + make_interval(days => p_days) end);
    given := given + 1;
  end loop;
  return jsonb_build_object('given', given, 'missing', to_jsonb(missing));
end $$;

drop function if exists public.gogu_items_list();
create function public.gogu_items_list() returns table(id text, name text, kind text, descr text, tier text, slot text)
language sql stable security definer set search_path = public as $$
  select id, name, kind, descr, tier, slot from public.gogu_items order by kind, name;
$$;

-- ---------- 실행 권한 ----------
do $$
declare f text;
begin
  foreach f in array array[
    'gogu_rand_code(int)','gogu_calc(jsonb)','gogu_require_admin()',
    'gogu_ensure_profile()','gogu_set_nickname(text)','gogu_set_title(text)',
    'gogu_load()','gogu_save(jsonb,timestamptz)','gogu_my_rank(text)',
    'gogu_clan_my()','gogu_clan_create(text)','gogu_clan_join(text)','gogu_clan_leave()',
    'gogu_gifts_list()','gogu_gift_claim(uuid)','gogu_admin_lookup(text)',
    'gogu_admin_give(text[],text,text,int,text,int)'
  ] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array[
    'gogu_ensure_profile()','gogu_set_nickname(text)','gogu_set_title(text)',
    'gogu_load()','gogu_save(jsonb,timestamptz)','gogu_my_rank(text)',
    'gogu_clan_my()','gogu_clan_create(text)','gogu_clan_join(text)','gogu_clan_leave()',
    'gogu_gifts_list()','gogu_gift_claim(uuid)','gogu_admin_lookup(text)',
    'gogu_admin_give(text[],text,text,int,text,int)'
  ] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- 랭킹·아이템 목록·시즌은 로그인 전에도 볼 수 있습니다
  foreach f in array array['gogu_ranking(text,boolean,int,int)','gogu_clan_ranking(int)','gogu_items_list()','gogu_season()'] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated', f);
  end loop;
end $$;
