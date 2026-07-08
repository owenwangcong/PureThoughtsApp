-- 本地开发种子数据(仅 `supabase db reset` 时在本地执行,不进生产)
-- 全局功课主清单示例(生产环境由 App 管理员维护)
insert into public.practice_types (name_hant, name_hans, unit, is_custom, sort_order) values
  ('誦經', '诵经', 'volume',     false, 1),
  ('持咒', '持咒', 'recitation', false, 2),
  ('禮懺', '礼忏', 'recitation', false, 3),
  ('念佛', '念佛', 'count',      false, 4),
  ('靜坐', '静坐', 'minute',     false, 5);
