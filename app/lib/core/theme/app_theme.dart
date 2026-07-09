import 'package:flutter/material.dart';

/// 全局主题(PRD v0.5.4 §11 视觉基调,参照官网视觉):
/// 浅色 = 宣纸暖白底 + 古铜金主色(「善護念」题字金)+ 深棕文字;
/// 深色 = 暖调深灰(**不用纯黑**),金色降饱和保持可读。
/// 规范:8pt 网格 · 控件圆角 12 / 卡片 16 / 弹层 24 · 触控 ≥48pt ·
/// 按钮三级层级(filled / tonal·outlined / text)· 正文行高 1.5。
abstract final class AppTheme {
  /// 古铜金(取自官网题字与莲花标)
  static const seed = Color(0xFF8A6D3B);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    scheme = isDark
        ? scheme.copyWith(
            // 降饱和的金,暗底可读
            primary: const Color(0xFFD6BC7E),
            onPrimary: const Color(0xFF3B2F0F),
            primaryContainer: const Color(0xFF574722),
            onPrimaryContainer: const Color(0xFFF2E3BC),
            surface: const Color(0xFF1D1A13),
            onSurface: const Color(0xFFE9E2D2),
            onSurfaceVariant: const Color(0xFFCFC6B0),
            surfaceContainerLowest: const Color(0xFF15130E),
            surfaceContainerLow: const Color(0xFF221E15),
            surfaceContainer: const Color(0xFF262217),
            surfaceContainerHigh: const Color(0xFF2C2719),
            surfaceContainerHighest: const Color(0xFF332D1E),
            outline: const Color(0xFF8F8568),
            outlineVariant: const Color(0xFF4A4433),
          )
        : scheme.copyWith(
            primary: seed,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFEADDBE),
            onPrimaryContainer: const Color(0xFF453413),
            surface: const Color(0xFFFDFAF2), // 卡片纸白
            onSurface: const Color(0xFF433A28), // 深棕正文(非纯黑)
            onSurfaceVariant: const Color(0xFF6F654E),
            surfaceContainerLowest: const Color(0xFFFFFEFA),
            surfaceContainerLow: const Color(0xFFFBF6EA),
            surfaceContainer: const Color(0xFFF6F0DF),
            surfaceContainerHigh: const Color(0xFFF0E8D3),
            surfaceContainerHighest: const Color(0xFFE9DFC6),
            outline: const Color(0xFFA3987B),
            outlineVariant: const Color(0xFFDDD3B8),
          );

    // 宣纸底(浅)/ 暖黑底(深,非 #000)
    final scaffoldBg =
        isDark ? const Color(0xFF15130E) : const Color(0xFFF6F1E4);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
    );

    // 字体层级:大标题厚重、正文行高 1.5(适老可读性)
    final text = base.textTheme.copyWith(
      headlineMedium:
          base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall:
          base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium:
          base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
    );

    const controlRadius = BorderRadius.all(Radius.circular(12));
    const controlShape = RoundedRectangleBorder(borderRadius: controlRadius);

    return base.copyWith(
      textTheme: text,

      // 页面切换:滑动+淡出(全平台统一)
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),

      // 按钮层级:primary=filled / secondary=tonal·outlined / tertiary=text
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: controlShape,
          textStyle: text.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: controlShape,
          side: BorderSide(color: scheme.outline),
          textStyle: text.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      // 输入:柔和填充 + 圆角,聚焦金色描边
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      // 层级靠多级 surface 色,不靠描边与重阴影
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.6),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        selectedColor: scheme.primaryContainer,
        showCheckmark: true,
      ),

      // 漂浮元素才用柔和阴影
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
        backgroundColor:
            isDark ? scheme.surfaceContainerHighest : const Color(0xFF433A28),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: isDark ? scheme.onSurface : const Color(0xFFFDFAF2),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: controlShape,
      ),
    );
  }
}
