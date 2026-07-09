import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/theme/app_theme.dart';

void main() {
  group('AppTheme(PRD v0.5.4 视觉基调)', () {
    test('浅色:古铜金主色 + 宣纸底,Material 3', () {
      final t = AppTheme.light;
      expect(t.useMaterial3, true);
      expect(t.colorScheme.primary, AppTheme.seed);
      expect(t.scaffoldBackgroundColor, isNot(Colors.white));
      // 正文非纯黑(暖棕)
      expect(t.colorScheme.onSurface, isNot(Colors.black));
    });

    test('深色:不用纯黑,金色降饱和后与浅色主色不同', () {
      final t = AppTheme.dark;
      expect(t.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
      expect(t.colorScheme.surface, isNot(const Color(0xFF000000)));
      expect(t.colorScheme.primary, isNot(AppTheme.seed));
      expect(t.colorScheme.brightness, Brightness.dark);
    });

    test('组件规范:按钮触控高度 ≥48,正文行高 1.5', () {
      final t = AppTheme.light;
      final minSize = t.filledButtonTheme.style?.minimumSize?.resolve({});
      expect(minSize, isNotNull);
      expect(minSize!.height, greaterThanOrEqualTo(48));
      expect(t.textTheme.bodyMedium?.height, 1.5);
    });
  });
}
