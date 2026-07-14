import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';

/// 新增群自定义功课项(名称 + 分类 + 单位;成员均可加,PRD §4.1)。
/// 返回新建项的 id;取消或失败返回 null。
Future<String?> showAddPracticeTypeDialog(
  BuildContext context, {
  required String groupId,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = TextEditingController();
  var category = 'other';
  var unit = 'recitation';

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.addPracticeType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.practiceTypeName),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: InputDecoration(labelText: l10n.categoryTitle),
              items: [
                for (final c in practiceCategories)
                  DropdownMenuItem(value: c, child: Text(categoryLabel(l10n, c))),
              ],
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: unit,
              decoration: InputDecoration(labelText: l10n.unitTitle),
              items: [
                for (final u in practiceUnits)
                  DropdownMenuItem(value: u, child: Text(unitLabel(l10n, u))),
              ],
              onChanged: (v) => setState(() => unit = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: Text(l10n.submit)),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty || !context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final row = await Supabase.instance.client
        .from('practice_types')
        .insert({
          'group_id': groupId,
          'name_hant': name.text.trim(),
          'name_hans': name.text.trim(),
          'category': category,
          'unit': unit,
          'is_custom': true,
        })
        .select('id')
        .single();
    return row['id'] as String;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    return null;
  }
}
