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

/// practice_category 枚举 → 本地化分类文案(PRD v0.5.2:經咒懺是分类,功课项须具体)
String categoryLabel(AppLocalizations l10n, String category) => switch (category) {
      'sutra' => l10n.categorySutra,
      'mantra' => l10n.categoryMantra,
      'repentance' => l10n.categoryRepentance,
      'buddha_name' => l10n.categoryBuddhaName,
      'meditation' => l10n.categoryMeditation,
      _ => l10n.categoryOther,
    };

/// 展示顺序
const practiceCategories = <String>[
  'sutra',
  'mantra',
  'repentance',
  'buddha_name',
  'meditation',
  'other',
];
