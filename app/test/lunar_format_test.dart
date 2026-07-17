import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/almanac/lunar_format.dart';

void main() {
  group('农历文案渲染', () {
    test('日名:初一/初十/十五/二十/廿三/三十', () {
      expect(lunarDayText(1), '初一');
      expect(lunarDayText(10), '初十');
      expect(lunarDayText(15), '十五');
      expect(lunarDayText(20), '二十');
      expect(lunarDayText(23), '廿三');
      expect(lunarDayText(30), '三十');
    });

    test('月名:正月/冬月/臘月(简体腊月)', () {
      expect(lunarMonthText(1, false, hans: false), '正月');
      expect(lunarMonthText(11, false, hans: false), '冬月');
      expect(lunarMonthText(12, false, hans: false), '臘月');
      expect(lunarMonthText(12, false, hans: true), '腊月');
    });

    test('闰月前缀:簡體闰/繁體閏', () {
      expect(lunarMonthText(4, true, hans: false), '閏四月');
      expect(lunarMonthText(4, true, hans: true), '闰四月');
    });

    test('格子副标签:初一显示月名,其余显示日名', () {
      expect(lunarCellLabel(4, 1, false, hans: false), '四月');
      expect(lunarCellLabel(4, 8, false, hans: false), '初八');
      expect(lunarCellLabel(12, 1, true, hans: true), '闰腊月');
    });

    test('完整农历:農曆四月初八 / 农历闰六月十五', () {
      expect(lunarFullText(4, 8, false, hans: false), '農曆四月初八');
      expect(lunarFullText(6, 15, true, hans: true), '农历闰六月十五');
    });
  });
}
