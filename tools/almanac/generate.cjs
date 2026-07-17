// 佛历数据生成器(设计:docs/design/buddhist-calendar.md §3)
// 用法:cd tools/almanac && npm install && npm run generate
// 产物(均提交进库):
//   app/assets/almanac/festivals.json          节日目录
//   app/assets/almanac/almanac_<year>.json     2026–2075 逐日农历 + 节日 + 十斋日
//   supabase/migrations/20260716000013_almanac_data.sql   服务端特殊日数据(幂等 upsert)
// 注意:该 migration 一旦应用到生产,再改清单须把产物文件名换新时间戳(见 README)。

const fs = require('fs');
const path = require('path');
const { Solar } = require('lunar-javascript');
const FESTIVALS = require('./festivals.cjs');

const START_YEAR = 2026;
const END_YEAR = 2075;
const ZHAI_TEN = new Set([1, 8, 14, 15, 18, 23, 24, 28, 29, 30]); // 十斋日农历日号
const REPO = path.resolve(__dirname, '..', '..');
const ASSET_DIR = path.join(REPO, 'app', 'assets', 'almanac');
const DATA_MIGRATION = path.join(
  REPO, 'supabase', 'migrations', '20260716000013_almanac_data.sql');

// ---------- 第一遍:逐日农历(前后各垫 3 个月,保证边界农历月完整) ----------
const perDate = new Map();   // 'YYYY-MM-DD' -> {ly, lm, leap, ld}
const monthMax = new Map();  // 'ly|lm|leap' -> 该农历月最大日号
const solarOf = new Map();   // 'ly|lm|leap|ld' -> 'YYYY-MM-DD'

const pad2 = (n) => String(n).padStart(2, '0');
const cur = new Date(Date.UTC(START_YEAR - 1, 9, 1)); // 前一年 10-01
const end = new Date(Date.UTC(END_YEAR + 1, 2, 31));  // 后一年 03-31
while (cur <= end) {
  const y = cur.getUTCFullYear();
  const m = cur.getUTCMonth() + 1;
  const d = cur.getUTCDate();
  const key = `${y}-${pad2(m)}-${pad2(d)}`;
  const lunar = Solar.fromYmd(y, m, d).getLunar();
  const rawMonth = lunar.getMonth(); // 负数 = 闰月
  const rec = {
    ly: lunar.getYear(),
    lm: Math.abs(rawMonth),
    leap: rawMonth < 0,
    ld: lunar.getDay(),
  };
  perDate.set(key, rec);
  const mk = `${rec.ly}|${rec.lm}|${rec.leap ? 1 : 0}`;
  monthMax.set(mk, Math.max(monthMax.get(mk) || 0, rec.ld));
  solarOf.set(`${mk}|${rec.ld}`, key);
  cur.setUTCDate(cur.getUTCDate() + 1);
}

// ---------- 第二遍:节日落位(仅非闰月;d=30 小月回退到月末) ----------
const festByDate = new Map(); // 'YYYY-MM-DD' -> [festival id...]
for (const [mk, maxDay] of monthMax) {
  const [ly, lm, leap] = mk.split('|').map(Number);
  if (leap) continue; // 闰月不过节
  for (const f of FESTIVALS) {
    if (f.m !== lm) continue;
    const day = Math.min(f.d, maxDay); // 九月三十等小月回退
    const solar = solarOf.get(`${mk}|${day}`);
    if (!solar) continue; // 垫边范围外的不完整月
    const y = Number(solar.slice(0, 4));
    if (y < START_YEAR || y > END_YEAR) continue;
    if (!festByDate.has(solar)) festByDate.set(solar, []);
    festByDate.get(solar).push(f.id);
  }
}

// ---------- 校验断言(错则中止,不产出) ----------
function assert(cond, msg) {
  if (!cond) {
    console.error(`断言失败:${msg}`);
    process.exit(1);
  }
}
// 锚点:2026 春节 2026-02-17;2027 春节 2027-02-06;2026 佛诞 2026-05-24(香港佛诞公众假期)
assert(solarOf.get('2026|1|0|1') === '2026-02-17', `2026 正月初一应为 2026-02-17,实得 ${solarOf.get('2026|1|0|1')}`);
assert(solarOf.get('2027|1|0|1') === '2027-02-06', `2027 正月初一应为 2027-02-06,实得 ${solarOf.get('2027|1|0|1')}`);
assert((festByDate.get('2026-05-24') || []).includes('sakyamuni_birth'), '2026-05-24 应为佛诞(四月初八)');
// 结构:每个节日在 50 年里出现 49–51 次(农历年与公历年错位允许 ±1)
const festCount = new Map();
for (const ids of festByDate.values()) for (const id of ids) festCount.set(id, (festCount.get(id) || 0) + 1);
for (const f of FESTIVALS) {
  const n = festCount.get(f.id) || 0;
  assert(n >= END_YEAR - START_YEAR && n <= END_YEAR - START_YEAR + 2,
    `${f.id} 50 年内出现 ${n} 次,超出预期范围`);
}

// ---------- 产出 1:App 资产 ----------
fs.mkdirSync(ASSET_DIR, { recursive: true });
fs.writeFileSync(
  path.join(ASSET_DIR, 'festivals.json'),
  JSON.stringify(FESTIVALS.map((f) => ({
    id: f.id, m: f.m, d: f.d, hant: f.hant, hans: f.hans,
    short_hant: f.shortHant, short_hans: f.shortHans, major: f.major,
  })), null, 0),
);

const isLeapYear = (y) => (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
const DAYS_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
for (let y = START_YEAR; y <= END_YEAR; y++) {
  const days = [];
  const fest = {};
  const zhai = [];
  for (let m = 1; m <= 12; m++) {
    const dim = m === 2 && isLeapYear(y) ? 29 : DAYS_IN_MONTH[m - 1];
    for (let d = 1; d <= dim; d++) {
      const key = `${y}-${pad2(m)}-${pad2(d)}`;
      const rec = perDate.get(key);
      days.push([rec.lm, rec.ld, rec.leap ? 1 : 0]);
      const md = `${pad2(m)}-${pad2(d)}`;
      if (festByDate.has(key)) fest[md] = festByDate.get(key);
      if (ZHAI_TEN.has(rec.ld)) zhai.push(md);
    }
  }
  const expect = isLeapYear(y) ? 366 : 365;
  assert(days.length === expect, `${y} 年应有 ${expect} 天,实得 ${days.length}`);
  fs.writeFileSync(
    path.join(ASSET_DIR, `almanac_${y}.json`),
    JSON.stringify({ y, days, fest, zhai }),
  );
}

// ---------- 产出 2:服务端数据 migration(仅特殊日,幂等 upsert) ----------
const byId = new Map(FESTIVALS.map((f) => [f.id, f]));
const pgTextArray = (items) =>
  items.length === 0 ? `'{}'` : `'{${items.map((s) => `"${s}"`).join(',')}}'`;

const rows = [];
const specialDates = new Set([...festByDate.keys()]);
for (const [key, rec] of perDate) {
  const y = Number(key.slice(0, 4));
  if (y < START_YEAR || y > END_YEAR) continue;
  if (ZHAI_TEN.has(rec.ld)) specialDates.add(key);
}
for (const key of [...specialDates].sort()) {
  const rec = perDate.get(key);
  const ids = festByDate.get(key) || [];
  const fs_ = ids.map((id) => byId.get(id));
  rows.push(
    `('${key}', ${rec.lm}, ${rec.ld}, ${rec.leap}, ` +
    `${pgTextArray(ids)}, ${pgTextArray(fs_.map((f) => f.hant))}, ` +
    `${pgTextArray(fs_.map((f) => f.hans))}, ${ZHAI_TEN.has(rec.ld)}, ` +
    `${fs_.some((f) => f.major)})`,
  );
}

let sql = `-- 由 tools/almanac/generate.cjs 生成,勿手改;再生成流程见 tools/almanac/README.md
-- 佛历特殊日(节日 + 十斋日)${START_YEAR}–${END_YEAR},共 ${rows.length} 行;幂等 upsert。
`;
const BATCH = 500;
for (let i = 0; i < rows.length; i += BATCH) {
  sql += `
insert into public.almanac_days
  (solar_date, lunar_month, lunar_day, is_leap_month, festival_ids, names_hant, names_hans, is_zhai_ten, has_major)
values
${rows.slice(i, i + BATCH).join(',\n')}
on conflict (solar_date) do update set
  lunar_month = excluded.lunar_month,
  lunar_day = excluded.lunar_day,
  is_leap_month = excluded.is_leap_month,
  festival_ids = excluded.festival_ids,
  names_hant = excluded.names_hant,
  names_hans = excluded.names_hans,
  is_zhai_ten = excluded.is_zhai_ten,
  has_major = excluded.has_major;
`;
}
fs.writeFileSync(DATA_MIGRATION, sql);

// ---------- sanity 报告(前 3 年节日对照,供人工与万年历核对) ----------
console.log(`资产:${END_YEAR - START_YEAR + 1} 个年度文件 + festivals.json → app/assets/almanac/`);
console.log(`migration:${rows.length} 行 → ${path.relative(REPO, DATA_MIGRATION)}`);
console.log('\n== 前 3 年节日对照(请与通行万年历抽查核对)==');
for (const key of [...festByDate.keys()].sort()) {
  const y = Number(key.slice(0, 4));
  if (y > START_YEAR + 2) continue;
  const rec = perDate.get(key);
  const names = festByDate.get(key).map((id) => byId.get(id).hans).join('、');
  console.log(`${key}  农历${rec.leap ? '闰' : ''}${rec.lm}月${String(rec.ld).padStart(2)}  ${names}`);
}
const zhai2026 = [];
for (const [key, rec] of perDate) {
  if (key.startsWith('2026-0') && key < '2026-04' && ZHAI_TEN.has(rec.ld)) zhai2026.push(key);
}
console.log(`\n== 2026 年 1–3 月十斋日 == \n${zhai2026.sort().join(' ')}`);
