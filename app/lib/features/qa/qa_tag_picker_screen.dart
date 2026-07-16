import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import 'qa_providers.dart';

/// 标签选择器(design/qa-search.md §7.2)。
/// 拉 /tags 全量(归一后约 600),本地过滤;多选,返回选中列表。
/// tags 参数是 OR:选多个 = 符合任一即显示。
class QaTagPickerScreen extends ConsumerStatefulWidget {
  const QaTagPickerScreen({super.key, this.initial = const []});

  final List<String> initial;

  @override
  ConsumerState<QaTagPickerScreen> createState() => _QaTagPickerScreenState();
}

class _QaTagPickerScreenState extends ConsumerState<QaTagPickerScreen> {
  late final Set<String> _selected = {...widget.initial};
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tagsAsync = ref.watch(qaTagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qaTagPickerTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _filter = v.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.qaTagPickerHint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.qaTagPickerOr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          Expanded(
            child: tagsAsync.when(
              loading: () => const SkeletonList(),
              error: (_, _) =>
                  ErrorRetry(onRetry: () => ref.invalidate(qaTagsProvider)),
              data: (all) {
                final list = _filter.isEmpty
                    ? all
                    : all.where((t) => t.contains(_filter)).toList();
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in list)
                        FilterChip(
                          label: Text(t),
                          selected: _selected.contains(t),
                          onSelected: (on) => setState(
                            () => on ? _selected.add(t) : _selected.remove(t),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
        ),
        child: FilledButton(
          onPressed: () => context.pop(_selected.toList()),
          child: Text(l10n.qaTagPickerDone(_selected.length)),
        ),
      ),
    );
  }
}
