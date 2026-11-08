-- 운영자(대표) 계정은 랭킹·클랜 점수·시즌 보상에서 제외
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
        and not p.is_admin
        and (not coalesce(p_new, false) or p.created_at > now() - interval '7 days')
        and (case when p_kind = 'pc' then r.best_pc > 1 else r.best_ps > 0 end)
    ) v
    order by 1
    limit greatest(1, least(coalesce(p_limit, 50), 100));
end $$;

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
  if st in ('hold','banned') then return jsonb_build_object('hidden', true, 'value', mine); end if;
  select count(*) + 1 into rk from public.gogu_records r join public.gogu_profiles p on p.id = r.user_id
    where r.season = s and p.flag_state in ('ok','warned') and not p.is_admin
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
    where p.clan_id is not null and r.best_ps > 0 and p.flag_state in ('ok','warned') and not p.is_admin
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
