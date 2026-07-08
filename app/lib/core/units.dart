import '../l10n/gen/app_localizations.dart';

/// practice_unit 枚举 → 本地化单位文案(volume=部 recitation=遍 count=次 minute=分钟)
String unitLabel(AppLocalizations l10n, String unit) => switch (unit) {
      'volume' => l10n.unitVolume,
      'recitation' => l10n.unitRecitation,
      'count' => l10n.unitCount,
      'minute' => l10n.unitMinute,
      _ => unit,
    };

const practiceUnits = ['volume', 'recitation', 'count', 'minute'];
