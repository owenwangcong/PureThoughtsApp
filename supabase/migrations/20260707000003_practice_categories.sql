-- ============================================================================
-- 功课项模型修正(PRD v0.5.2 §4.1):
-- 經/咒/懺是分类而非功课项,报数必须具体到条目(金剛經/大悲咒/地藏懺…)。
-- practice_types 增加 category 列,清单与报数选择器按分类分组。
-- ============================================================================

create type public.practice_category as enum
  ('sutra',        -- 經
   'mantra',       -- 咒
   'repentance',   -- 懺
   'buddha_name',  -- 念佛/聖號
   'meditation',   -- 靜坐
   'other');

alter table public.practice_types
  add column category public.practice_category not null default 'other';

create index idx_practice_types_category on public.practice_types (category);
