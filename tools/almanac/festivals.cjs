// 精选佛教节日清单(PRD v0.5.15 §5.2 / 设计 §3.3)—— 本文件是唯一人工维护点。
// 字段:id 稳定标识 · m/d 农历月日(仅匹配非闰月;d=30 而当月为小月时回退到廿九)
//       hant/hans 全名(通知/佛历卡用) · shortHant/shortHans 短名(日历格子用,≤4 字)
//       major=true 为重大节日(★):提前一天生成预告通知。
// 改动后:cd tools/almanac && npm run generate,提交重新生成的资产与 migration。
module.exports = [
  { id: 'mile_birth',        m: 1,  d: 1,  hant: '彌勒菩薩聖誕', hans: '弥勒菩萨圣诞', shortHant: '彌勒誕', shortHans: '弥勒诞', major: true },
  { id: 'dingguang_birth',   m: 1,  d: 6,  hant: '定光佛聖誕', hans: '定光佛圣诞', shortHant: '定光佛', shortHans: '定光佛', major: false },
  { id: 'sakyamuni_ordain',  m: 2,  d: 8,  hant: '釋迦牟尼佛出家日', hans: '释迦牟尼佛出家日', shortHant: '佛出家', shortHans: '佛出家', major: true },
  { id: 'sakyamuni_nirvana', m: 2,  d: 15, hant: '釋迦牟尼佛涅槃日', hans: '释迦牟尼佛涅槃日', shortHant: '佛涅槃', shortHans: '佛涅槃', major: true },
  { id: 'guanyin_birth',     m: 2,  d: 19, hant: '觀世音菩薩聖誕', hans: '观世音菩萨圣诞', shortHant: '觀音誕', shortHans: '观音诞', major: true },
  { id: 'puxian_birth',      m: 2,  d: 21, hant: '普賢菩薩聖誕', hans: '普贤菩萨圣诞', shortHant: '普賢誕', shortHans: '普贤诞', major: false },
  { id: 'zhunti_birth',      m: 3,  d: 16, hant: '準提菩薩聖誕', hans: '准提菩萨圣诞', shortHant: '準提誕', shortHans: '准提诞', major: false },
  { id: 'wenshu_birth',      m: 4,  d: 4,  hant: '文殊菩薩聖誕', hans: '文殊菩萨圣诞', shortHant: '文殊誕', shortHans: '文殊诞', major: false },
  { id: 'sakyamuni_birth',   m: 4,  d: 8,  hant: '釋迦牟尼佛聖誕(浴佛節)', hans: '释迦牟尼佛圣诞(浴佛节)', shortHant: '佛誕', shortHans: '佛诞', major: true },
  { id: 'yaowang_birth',     m: 4,  d: 28, hant: '藥王菩薩聖誕', hans: '药王菩萨圣诞', shortHant: '藥王誕', shortHans: '药王诞', major: false },
  { id: 'qielan_birth',      m: 5,  d: 13, hant: '伽藍菩薩聖誕', hans: '伽蓝菩萨圣诞', shortHant: '伽藍誕', shortHans: '伽蓝诞', major: false },
  { id: 'weituo_birth',      m: 6,  d: 3,  hant: '韋馱菩薩聖誕', hans: '韦驮菩萨圣诞', shortHant: '韋馱誕', shortHans: '韦驮诞', major: false },
  { id: 'guanyin_enlight',   m: 6,  d: 19, hant: '觀世音菩薩成道日', hans: '观世音菩萨成道日', shortHant: '觀音成道', shortHans: '观音成道', major: true },
  { id: 'dashizhi_birth',    m: 7,  d: 13, hant: '大勢至菩薩聖誕', hans: '大势至菩萨圣诞', shortHant: '勢至誕', shortHans: '势至诞', major: false },
  { id: 'ullambana',         m: 7,  d: 15, hant: '佛歡喜日(盂蘭盆節)', hans: '佛欢喜日(盂兰盆节)', shortHant: '盂蘭盆', shortHans: '盂兰盆', major: true },
  { id: 'longshu_birth',     m: 7,  d: 24, hant: '龍樹菩薩聖誕', hans: '龙树菩萨圣诞', shortHant: '龍樹誕', shortHans: '龙树诞', major: false },
  { id: 'dizang_birth',      m: 7,  d: 30, hant: '地藏菩薩聖誕', hans: '地藏菩萨圣诞', shortHant: '地藏誕', shortHans: '地藏诞', major: true },
  { id: 'randeng_birth',     m: 8,  d: 22, hant: '燃燈佛聖誕', hans: '燃灯佛圣诞', shortHant: '燃燈佛', shortHans: '燃灯佛', major: false },
  { id: 'guanyin_ordain',    m: 9,  d: 19, hant: '觀世音菩薩出家日', hans: '观世音菩萨出家日', shortHant: '觀音出家', shortHans: '观音出家', major: true },
  { id: 'yaoshi_birth',      m: 9,  d: 30, hant: '藥師琉璃光如來聖誕', hans: '药师琉璃光如来圣诞', shortHant: '藥師誕', shortHans: '药师诞', major: false },
  { id: 'damo_birth',        m: 10, d: 5,  hant: '達摩祖師聖誕', hans: '达摩祖师圣诞', shortHant: '達摩誕', shortHans: '达摩诞', major: false },
  { id: 'amituofo_birth',    m: 11, d: 17, hant: '阿彌陀佛聖誕', hans: '阿弥陀佛圣诞', shortHant: '彌陀誕', shortHans: '弥陀诞', major: true },
  { id: 'sakyamuni_enlight', m: 12, d: 8,  hant: '釋迦牟尼佛成道日(臘八)', hans: '释迦牟尼佛成道日(腊八)', shortHant: '佛成道', shortHans: '佛成道', major: true },
  { id: 'huayan_birth',      m: 12, d: 29, hant: '華嚴菩薩聖誕', hans: '华严菩萨圣诞', shortHant: '華嚴誕', shortHans: '华严诞', major: false },
];
