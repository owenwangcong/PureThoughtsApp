// 农历文案渲染(纯函数,零依赖,便于单测)。
// 数据侧只存数字(月/日/闰),文案在客户端按简繁生成 —— 避免资产里存两套字符串
// (简繁仅「臘/腊、閏/闰」两字有差异,见设计 docs/design/buddhist-calendar.md §4.1)。

const _dayNames = [
  '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十', //
  '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十', //
  '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十',
];

const _monthNamesHant = [
  '正月', '二月', '三月', '四月', '五月', '六月', //
  '七月', '八月', '九月', '十月', '冬月', '臘月',
];

/// 农历日名:初一…三十
String lunarDayText(int day) => _dayNames[day - 1];

/// 农历月名:正月…臘月/腊月,闰月加「閏/闰」前缀
String lunarMonthText(int month, bool leap, {required bool hans}) {
  var name = _monthNamesHant[month - 1];
  if (hans && month == 12) name = '腊月';
  if (!leap) return name;
  return (hans ? '闰' : '閏') + name;
}

/// 日历格子副标签:初一显示月名(通行农历日历惯例),其余显示日名
String lunarCellLabel(int month, int day, bool leap, {required bool hans}) =>
    day == 1 ? lunarMonthText(month, leap, hans: hans) : lunarDayText(day);

/// 完整农历日期:「農曆四月初八」/「农历闰六月十五」
String lunarFullText(int month, int day, bool leap, {required bool hans}) =>
    (hans ? '农历' : '農曆') +
    lunarMonthText(month, leap, hans: hans) +
    lunarDayText(day);
