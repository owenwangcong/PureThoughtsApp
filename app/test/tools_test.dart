import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/tools/bell.dart';

void main() {
  group('计时显示 formatMmSs', () {
    test('整分与秒位补零', () {
      expect(formatMmSs(const Duration(minutes: 20)), '20:00');
      expect(formatMmSs(const Duration(minutes: 5, seconds: 7)), '05:07');
      expect(formatMmSs(const Duration(seconds: 59)), '00:59');
      expect(formatMmSs(Duration.zero), '00:00');
    });

    test('超过一小时以分钟累计显示', () {
      expect(formatMmSs(const Duration(minutes: 90, seconds: 3)), '90:03');
    });
  });
}
