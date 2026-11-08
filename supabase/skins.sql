-- 고구마게임 스킨 아이템 등록 (Supabase SQL Editor에 붙여넣고 Run)
-- 분류: tier = 유료(paid) / 이벤트(event), slot = 고구마(potato) / 화로(brazier) / 불(fire)
-- 무료 스킨은 서버 등록 없이 누구나 사용합니다. (고구마: 기본·호박·밤·자색 / 화로: 기본·은빛·구리·청동 / 불: 기본·푸른·보라·노을)
insert into public.gogu_items(id,name,kind,descr,tier,slot) values
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

-- 무료로 바뀐 스킨은 서버 등록에서 뺍니다 (아무도 갖고 있지 않을 때만)
delete from public.gogu_items i
 where i.id in ('skin_p_chestnut','skin_p_violet','skin_f_purple')
   and not exists(select 1 from public.gogu_user_items u where u.item_id=i.id)
   and not exists(select 1 from public.gogu_gifts g where g.item_id=i.id);
