-- ============================================================
-- 초대 코드(붕어빵) · 친구 초대 보상 · 출석 보상 · 7배 버터
--  Supabase SQL Editor 에 붙여넣고 Run (여러 번 실행해도 안전합니다)
--  * 7배 버터 = 일정 시간 동안 수입 7배 (perk_butter7, 만료 시각까지)
--  * 붕어빵 초대 코드: BUNGEOPPANG / 붕어빵 → 황금고구마 · 붕어빵 화로 · 서리 불꽃 영구 + 버터 60분, 11/30 까지, 계정당 1회
--  * 친구 초대: 내 코드(GOGU-....)로 가입한 새 계정과 나 둘 다 버터 30분 (초대한 쪽은 최대 20명까지)
--  * 출석: 하루 1번 버터 10분, 7일 연속 시 60분
-- ============================================================

-- ---------- 아이템 ----------
insert into public.gogu_items(id,name,kind,descr,tier,slot) values
 ('perk_butter7','7배 버터','perk','정해진 시간 동안 수입이 7배가 돼요',null,null),
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

-- ---------- 내부 도우미: 7배 버터 늘리기 (한 번에 최대 3시간까지만 쌓임) ----------
create or replace function public.gogu_add_butter(p_user uuid, p_min int) returns void
language plpgsql security definer set search_path = public as $$
declare cur timestamptz; nxt timestamptz;
begin
  if p_min is null or p_min < 1 then return; end if;
  select expires_at into cur from public.gogu_user_items where user_id = p_user and item_id = 'perk_butter7';
  nxt := least(greatest(coalesce(cur, now()), now()) + make_interval(mins => p_min), now() + interval '3 hours');
  insert into public.gogu_user_items(user_id, item_id, source, expires_at) values (p_user, 'perk_butter7', 'butter', nxt)
  on conflict (user_id, item_id) do update set expires_at = nxt;
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

revoke all on function public.gogu_checkin() from public, anon;
grant execute on function public.gogu_checkin() to authenticated;
revoke all on function public.gogu_redeem_code(text) from public, anon;
grant execute on function public.gogu_redeem_code(text) to authenticated;
revoke all on function public.gogu_referral_my() from public, anon;
grant execute on function public.gogu_referral_my() to authenticated;
revoke all on function public.gogu_admin_promo_stats() from public, anon;
grant execute on function public.gogu_admin_promo_stats() to authenticated;
notify pgrst, 'reload schema';
