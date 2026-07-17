# tools/almanac · 佛历数据生成器

预生成 **2026–2075(50 年)** 逐日农历 + 精选佛教节日 + 十斋日数据,供 App 离线使用与服务端通知排程。
设计文档:[`docs/design/buddhist-calendar.md`](../../docs/design/buddhist-calendar.md)。

## 数据源

[lunar-javascript](https://github.com/6tail/lunar-javascript)(6tail 官方库,佛历/农历算法与其 Dart/Java/Python 版同源)。

## 再生成流程

```sh
cd tools/almanac
npm install
npm run generate
```

产物(全部提交进库):

| 产物 | 用途 |
|---|---|
| `app/assets/almanac/festivals.json` | 节日目录(id → 简繁全名/短名/是否重大) |
| `app/assets/almanac/almanac_<year>.json` × 50 | 逐日农历(月/日/闰)+ 节日 + 十斋日,客户端离线读取 |
| `supabase/migrations/20260716000013_almanac_data.sql` | 服务端 `almanac_days` 特殊日数据(幂等 upsert),供 pg_cron 生成通知 |

生成器内置断言(春节/佛诞锚点、每年天数、节日出现次数),失败即中止不产出;
运行后会打印**前 3 年节日对照表**,请抽查与通行万年历一致后再提交。

## 改节日清单

1. 编辑 `festivals.cjs`(唯一人工维护点;字段说明见文件头注释)。
2. 重跑 `npm run generate`,核对 sanity 输出。
3. ⚠️ **若数据 migration 已应用到生产**:把 `generate.cjs` 里 `DATA_MIGRATION` 的文件名换成新时间戳再生成
   (旧 migration 不会重跑;新文件因 upsert 幂等,可安全覆盖旧数据)。客户端资产改动需随 App 发版生效。

## 口径备忘(与设计 §0 一致)

- 农历日按中国时间(UTC+8)定义,映射公历日期后全球同一天显示。
- 十斋日:农历每月初一、初八、十四、十五、十八、廿三、廿四、廿八、廿九、三十;小月无三十。闰月照常有斋日。
- 节日只落**非闰月**;配置日为三十而当月为小月时回退到月末(如藥師佛聖誕九月三十)。
