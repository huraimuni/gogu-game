-- 룰렛 스킨 칸을 모두 '랜덤'으로 통일 (선정 스킨 칸은 랜덤 유료 스킨(영구)으로)
update public.gogu_roulette_prizes set label = '랜덤 이벤트 스킨 (7일)'  where label = '이벤트 스킨 (7일, 무작위)';
update public.gogu_roulette_prizes set label = '랜덤 이벤트 스킨 (30일)' where label = '이벤트 스킨 (30일, 무작위)';
update public.gogu_roulette_prizes set label = '랜덤 유료 스킨 (7일)'    where label = '유료 스킨 (7일, 무작위)';
update public.gogu_roulette_prizes set label = '랜덤 유료 스킨 (30일)'   where label = '유료 스킨 (30일, 무작위)';
update public.gogu_roulette_prizes set label = '랜덤 유료 스킨 (90일)'   where label = '유료 스킨 (90일, 무작위)';
update public.gogu_roulette_prizes set label = '랜덤 유료 스킨 (영구)', kind = 'paid_skin', item_days = null where label = '선정 스킨 (영구)';
