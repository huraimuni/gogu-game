-- ============================================================
-- 초대 코드(붕어빵) · 친구 초대 보상 · 출석 보상 · 슈퍼장작
--  Supabase SQL Editor 에 붙여넣고 Run (여러 번 실행해도 안전합니다)
--  * 슈퍼장작 = 일정 시간 동안 수입 7배 (perk_butter7, 만료 시각까지)
--  * 붕어빵 초대 코드: BUNGEOPPANG / 붕어빵 → 황금고구마 · 붕어빵 화로 · 서리 불꽃 영구 + 슈퍼장작 60분, 11/30 까지, 계정당 1회
--  * 친구 초대: 내 코드(GOGU-....)로 가입한 새 계정과 나 둘 다 슈퍼장작 30분 (초대한 쪽은 최대 20명까지)
--  * 출석: 하루 1번 슈퍼장작 10분, 7일 연속 시 60분
-- ============================================================

-- ---------- 아이템 ----------
insert into public.gogu_items(id,name,kind,descr,tier,slot) values
 ('perk_butter7','슈퍼장작 타임','perk','정해진 시간 동안 수입이 7배가 돼요',null,null),
 ('skin_b_bungeo','붕어빵 화로','skin','화로 외형 (붕어빵 초대 전용)','event','brazier')
on conflict (id) do update set name=excluded.name, kind=excluded.kind, descr=excluded.descr, tier=excluded.tier, slot=excluded.slot;

update public.gogu_items set name='서리 불꽃' where id='skin_f_ice';   -- 게임 화면의 이름과 맞춤

-- ---------- 컬럼/테이블 ----------
alter table public.gogu_profiles
  add column if not exists last_checkin date,
  add column if not exists checkin_streak int not null default 0;

create table if not exists public.gogu_promos(
  id text primary key,
  label text not null,
  codes text[] not null,
  items text[] not null default '{}',
  butter_min int not null default 0,
  expires_at timestamptz
);
create table if not exists public.gogu_promo_redeems(
  user_id uuid not null references auth.users(id) on delete cascade,
  promo_id text not null references public.gogu_promos(id) on delete cascade,
  at timestamptz not null default now(),
  primary key(user_id, promo_id)
);
create table if not exists public.gogu_referrals(
  invitee uuid primary key references auth.users(id) on delete cascade,
  inviter uuid not null references auth.users(id) on delete cascade,
  rewarded boolean not null default false,
  at timestamptz not null default now()
);
create index if not exists gogu_referrals_inviter_idx on public.gogu_referrals(inviter);

do $$ declare t text; begin
  foreach t in array array['gogu_promos','gogu_promo_redeems','gogu_referrals'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

insert into public.gogu_promos(id,label,codes,items,butter_min,expires_at) values
 ('bread','붕어빵 초대',array['BUNGEOPPANG','붕어빵'],array['skin_p_gold','skin_b_bungeo','skin_f_ice'],60,
  timestamptz '2026-12-01 00:00:00+09')
on conflict (id) do update set label=excluded.label, codes=excluded.codes, items=excluded.items,
  butter_min=excluded.butter_min, expires_at=excluded.expires_at;

-- ---------- 내부 도우미: 슈퍼장작 늘리기 (한 번에 최대 12시간까지만 쌓임) ----------
create or replace function public.gogu_add_butter_s(p_user uuid, p_sec int) returns void
language plpgsql security definer set search_path = public as $$
declare cur timestamptz; nxt timestamptz;
begin
  if p_sec is null or p_sec < 1 then return; end if;
  select expires_at into cur from public.gogu_user_items where user_id = p_user and item_id = 'perk_butter7';
  nxt := least(greatest(coalesce(cur, now()), now()) + make_interval(secs => p_sec), now() + interval '12 hours');
  insert into public.gogu_user_items(user_id, item_id, source, expires_at) values (p_user, 'perk_butter7', 'butter', nxt)
  on conflict (user_id, item_id) do update set expires_at = nxt;
end $$;
revoke all on function public.gogu_add_butter_s(uuid, int) from public, anon, authenticated;
create or replace function public.gogu_add_butter(p_user uuid, p_min int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.gogu_add_butter_s(p_user, coalesce(p_min, 0) * 60);
end $$;
revoke all on function public.gogu_add_butter(uuid, int) from public, anon, authenticated;

-- ---------- 출석 (하루 1번, 한국 시간 기준) ----------
create or replace function public.gogu_checkin() returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.gogu_profiles; today date := (now() at time zone 'Asia/Seoul')::date; st int; mins int;
begin
  if uid is null then raise exception 'login required'; end if;
  select * into p from public.gogu_profiles where id = uid for update;
  if not found then raise exception 'no profile'; end if;
  if p.flag_state = 'banned' then raise exception '이용할 수 없는 계정이에요'; end if;
  if p.last_checkin = today then
    return jsonb_build_object('claimed', false, 'streak', p.checkin_streak);
  end if;
  st := case when p.last_checkin = today - 1 then p.checkin_streak + 1 else 1 end;
  mins := case when st % 7 = 0 then 60 else 10 end;
  update public.gogu_profiles set last_checkin = today, checkin_streak = st where id = uid;
  perform public.gogu_add_butter(uid, mins);
  return jsonb_build_object('claimed', true, 'streak', st, 'minutes', mins);
end $$;

-- ---------- 코드 입력 (붕어빵 초대 코드 · 친구 초대 코드 공용) ----------
create or replace function public.gogu_redeem_code(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); p public.gogu_profiles; norm text := upper(btrim(coalesce(p_code, '')));
  inv public.gogu_profiles; pr public.gogu_promos; it text; n int; names text[] := '{}'; nm text;
begin
  if uid is null then raise exception 'login required'; end if;
  p := public.gogu_ensure_profile();
  if p.flag_state = 'banned' then raise exception '이용할 수 없는 계정이에요'; end if;
  if norm = '' or length(norm) > 40 then raise exception '코드를 입력해 주세요'; end if;

  if norm like 'GOGU-%' then
    -- 친구 초대 코드
    select * into inv from public.gogu_profiles where code = norm;
    if not found then raise exception '없는 코드예요. 다시 확인해 주세요'; end if;
    if inv.id = uid then raise exception '내 코드는 쓸 수 없어요'; end if;
    if exists (select 1 from public.gogu_referrals where invitee = uid) then raise exception '이미 초대 코드를 사용했어요'; end if;
    if p.created_at < now() - interval '7 days' then raise exception '가입한 지 7일이 지난 계정은 쓸 수 없어요'; end if;
    select count(*) into n from public.gogu_referrals where inviter = inv.id and rewarded;
    insert into public.gogu_referrals(invitee, inviter, rewarded) values (uid, inv.id, n < 20);
    perform public.gogu_add_butter(uid, 30);
    if n < 20 then perform public.gogu_add_butter(inv.id, 30); end if;
    return jsonb_build_object('kind', 'referral', 'inviter', inv.nickname, 'minutes', 30);
  end if;

  -- 이벤트 초대 코드 (붕어빵)
  select * into pr from public.gogu_promos where norm = any(codes);
  if not found then raise exception '없는 코드예요. 다시 확인해 주세요'; end if;
  if pr.expires_at is not null and pr.expires_at <= now() then raise exception '기간이 지난 코드예요'; end if;
  begin
    insert into public.gogu_promo_redeems(user_id, promo_id) values (uid, pr.id);
  exception when unique_violation then
    raise exception '이미 사용한 코드예요';
  end;
  foreach it in array pr.items loop
    insert into public.gogu_user_items(user_id, item_id, source, expires_at) values (uid, it, 'promo', null)
    on conflict (user_id, item_id) do update set expires_at = null;
    select name into nm from public.gogu_items where id = it;
    names := names || coalesce(nm, it);
  end loop;
  perform public.gogu_add_butter(uid, pr.butter_min);
  return jsonb_build_object('kind', 'promo', 'label', pr.label, 'items', to_jsonb(names), 'minutes', pr.butter_min);
end $$;

-- ---------- 내 초대 현황 ----------
create or replace function public.gogu_referral_my() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'invited', (select count(*) from public.gogu_referrals where inviter = auth.uid() and rewarded),
    'max', 20,
    'used', exists (select 1 from public.gogu_referrals where invitee = auth.uid()),
    'promo_used', coalesce((select jsonb_agg(promo_id) from public.gogu_promo_redeems where user_id = auth.uid()), '[]'::jsonb));
$$;

-- ---------- 대표 운영자: 코드 사용 현황 ----------
create or replace function public.gogu_admin_promo_stats() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.gogu_is_admin() then raise exception 'forbidden'; end if;
  return jsonb_build_object(
    'promo', coalesce((select jsonb_agg(jsonb_build_object('promo', r.promo_id, 'nick', p.nickname, 'at', r.at) order by r.at desc)
                       from public.gogu_promo_redeems r join public.gogu_profiles p on p.id = r.user_id), '[]'::jsonb),
    'referrals', (select count(*) from public.gogu_referrals),
    'top_inviters', coalesce((select jsonb_agg(x) from (
        select jsonb_build_object('nick', p.nickname, 'n', count(*)) as x
        from public.gogu_referrals f join public.gogu_profiles p on p.id = f.inviter
        group by p.nickname order by count(*) desc limit 10) q), '[]'::jsonb));
end $$;

-- ---------- 매일 링크 교환 (붕어빵 방식): 공유 10초, 링크를 눌러 주면 서로 10초 (같은 링크는 사람당 하루 1번, 횟수 제한 없음) ----------
create table if not exists public.gogu_daily(
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  shared boolean not null default false,
  recv int not null default 0,
  gave int not null default 0,
  primary key(user_id, day)
);
create table if not exists public.gogu_link_claims(
  day date not null,
  sharer uuid not null references auth.users(id) on delete cascade,
  clicker uuid not null references auth.users(id) on delete cascade,
  primary key(day, sharer, clicker)
);
alter table public.gogu_daily enable row level security;
alter table public.gogu_link_claims enable row level security;
revoke all on public.gogu_daily from anon, authenticated;
revoke all on public.gogu_link_claims from anon, authenticated;

create or replace function public.gogu_share_bonus() returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); today date := (now() at time zone 'Asia/Seoul')::date; d public.gogu_daily;
begin
  if uid is null then raise exception 'login required'; end if;
  if exists (select 1 from public.gogu_profiles where id = uid and flag_state = 'banned') then raise exception '이용할 수 없는 계정이에요'; end if;
  insert into public.gogu_daily(user_id, day) values (uid, today) on conflict do nothing;
  select * into d from public.gogu_daily where user_id = uid and day = today for update;
  if d.shared then return jsonb_build_object('claimed', false, 'recv', d.recv, 'gave', d.gave); end if;
  update public.gogu_daily set shared = true where user_id = uid and day = today;
  perform public.gogu_add_butter_s(uid, 10);
  return jsonb_build_object('claimed', true, 'seconds', 10, 'recv', d.recv, 'gave', d.gave);
end $$;

create or replace function public.gogu_link_click(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); today date := (now() at time zone 'Asia/Seoul')::date;
  sh public.gogu_profiles; got int := 0;
begin
  if uid is null then raise exception 'login required'; end if;
  perform public.gogu_ensure_profile();
  select * into sh from public.gogu_profiles where code = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception '없는 링크예요'; end if;
  if sh.id = uid then raise exception '내 링크는 내가 눌러도 받을 수 없어요'; end if;
  if exists (select 1 from public.gogu_profiles where id = uid and flag_state = 'banned') then raise exception '이용할 수 없는 계정이에요'; end if;
  begin
    insert into public.gogu_link_claims(day, sharer, clicker) values (today, sh.id, uid);
  exception when unique_violation then
    raise exception '오늘 이 링크는 이미 눌렀어요. 내일 또 눌러 주세요';
  end;
  insert into public.gogu_daily(user_id, day) values (uid, today) on conflict do nothing;
  insert into public.gogu_daily(user_id, day) values (sh.id, today) on conflict do nothing;
  -- 하루 횟수 제한은 두지 않아요 (같은 링크는 사람당 하루 1번만)
  update public.gogu_daily set gave = gave + 1 where user_id = uid and day = today;
  perform public.gogu_add_butter_s(uid, 10); got := 10;
  update public.gogu_daily set recv = recv + 1 where user_id = sh.id and day = today;
  perform public.gogu_add_butter_s(sh.id, 10);
  return jsonb_build_object('seconds', got, 'sharer', sh.nickname);
end $$;

create or replace function public.gogu_daily_my() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'shared', coalesce((select shared from public.gogu_daily where user_id = auth.uid() and day = (now() at time zone 'Asia/Seoul')::date), false),
    'recv', coalesce((select recv from public.gogu_daily where user_id = auth.uid() and day = (now() at time zone 'Asia/Seoul')::date), 0),
    'gave', coalesce((select gave from public.gogu_daily where user_id = auth.uid() and day = (now() at time zone 'Asia/Seoul')::date), 0));
$$;

revoke all on function public.gogu_share_bonus() from public, anon;
grant execute on function public.gogu_share_bonus() to authenticated;
revoke all on function public.gogu_link_click(text) from public, anon;
grant execute on function public.gogu_link_click(text) to authenticated;
revoke all on function public.gogu_daily_my() from public, anon;
grant execute on function public.gogu_daily_my() to authenticated;

revoke all on function public.gogu_checkin() from public, anon;
grant execute on function public.gogu_checkin() to authenticated;
revoke all on function public.gogu_redeem_code(text) from public, anon;
grant execute on function public.gogu_redeem_code(text) to authenticated;
revoke all on function public.gogu_referral_my() from public, anon;
grant execute on function public.gogu_referral_my() to authenticated;
revoke all on function public.gogu_admin_promo_stats() from public, anon;
grant execute on function public.gogu_admin_promo_stats() to authenticated;

-- ---------- 닉네임: 일반 유저는 평생 1회만 변경 (nickname_admin.sql 최신 내용) ----------
-- 닉네임 규칙: 일반 유저 2~10자·평생 1회 (이후 변경은 캐쉬 아이템으로 판매 예정), 대표 운영자만 1~10자·횟수 제한 없음
create or replace function public.gogu_set_nickname(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare p public.gogu_profiles; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'login required'; end if;
  p_name := btrim(coalesce(p_name, ''));
  select * into p from public.gogu_profiles where id = uid;
  if not found then raise exception 'no profile'; end if;
  if p_name !~ (case when p.is_admin then '^[가-힣A-Za-z0-9_]{1,10}$' else '^[가-힣A-Za-z0-9_]{2,10}$' end) then
    raise exception '닉네임은 한글·영문·숫자 2~10자예요';
  end if;
  if p.nickname = p_name then return p.nickname; end if;
  if p.nickname_changed_at is not null and not p.is_admin then
    raise exception '닉네임은 한 번만 바꿀 수 있어요';
  end if;
  begin
    update public.gogu_profiles set nickname = p_name, nickname_changed_at = now() where id = uid;
  exception when unique_violation then
    raise exception '이미 사용 중인 닉네임이에요';
  end;
  return p_name;
end $$;
revoke all on function public.gogu_set_nickname(text) from public, anon;
grant execute on function public.gogu_set_nickname(text) to authenticated;

notify pgrst, 'reload schema';
