-- 배경 스킨 (장면 배경): slot = background. 무료 단색은 DB에 없어도 누구나 쓸 수 있고, 이벤트·유료만 등록해요.
alter table public.gogu_items drop constraint if exists gogu_items_slot_check;
alter table public.gogu_items add constraint gogu_items_slot_check check (slot in ('potato','brazier','fire','background'));
insert into public.gogu_items(id,name,kind,descr,tier,slot) values
 ('skin_g_stars','별빛 밤','skin','배경','event','background'),
 ('skin_g_snow','눈 내리는 밤','skin','배경','event','background'),
 ('skin_g_check','체크 노을','skin','배경','event','background'),
 ('skin_g_neon','네온 그리드','skin','배경','paid','background'),
 ('skin_g_aurora','오로라','skin','배경','paid','background'),
 ('skin_g_galaxy','은하수','skin','배경','paid','background'),
 ('skin_g_sakura','벚꽃','skin','배경','paid','background')
on conflict (id) do update set name=excluded.name, kind=excluded.kind, descr=excluded.descr, tier=excluded.tier, slot=excluded.slot;
notify pgrst, 'reload schema';
