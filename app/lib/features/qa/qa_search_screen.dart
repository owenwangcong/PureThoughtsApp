import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import 'qa_models.dart';
import 'qa_providers.dart';

/// 往期问答检索页(PRD §6 / design/qa-search.md §7.1)。
/// 默认(无 query 无标签)= 全部按日期倒序,首屏即内容;匿名可用。
class QaSearchScreen extends ConsumerStatefulWidget {
  const QaSearchScreen({super.key});

  @override
  ConsumerState<QaSearchScreen> createState() => _QaSearchScreenState();
}

class _QaSearchScreenState extends ConsumerState<QaSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 触底前 400px 追加下一页
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      ref.read(qaSearchProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(qaSearchProvider);
    final ctrl = ref.read(qaSearchProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qaTitle)),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: ctrl.onQueryChanged,
            onSubmitted: (t) => ctrl.submitQuery(t, force: true),
            onClear: () {
              _searchCtrl.clear();
              ctrl.clearQuery();
            },
          ),
          _TagBar(
            tags: state.tags,
            onRemove: (t) =>
                ctrl.setTags(state.tags.where((e) => e != t).toList()),
            onAdd: () async {
              final picked = await context.push<List<String>>(
                '/qa/tags',
                extra: state.tags,
              );
              if (picked != null) ctrl.setTags(picked);
            },
          ),
          if (state.searched && !state.loading && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.qaResultCount(state.total),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          Expanded(child: _Results(state: state, scrollController: _scrollCtrl)),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: l10n.qaSearchHint,
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TagBar extends StatelessWidget {
  const _TagBar({required this.tags, required this.onRemove, required this.onAdd});

  final List<String> tags;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final t in tags)
            InputChip(
              label: Text(t),
              onDeleted: () => onRemove(t),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(l10n.qaTagsAdd),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.state, required this.scrollController});

  final QaSearchState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (state.loading) return const SkeletonList();
    if (state.error) {
      return ErrorRetry(onRetry: () => ref.read(qaSearchProvider.notifier).refresh());
    }
    if (state.tooShort) {
      return EmptyState(icon: Icons.short_text, title: l10n.qaTooShort);
    }
    if (state.items.isEmpty) {
      // total == 0 是正常结果,不是错误
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.qaEmpty,
        hint: l10n.qaEmptyHint,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(qaSearchProvider.notifier).refresh(),
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, i) {
          if (i == state.items.length) {
            // 末尾:追加中转圈,或到底留白
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: state.loadingMore
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink(),
              ),
            );
          }
          return _QaCard(seg: state.items[i]);
        },
      ),
    );
  }
}

class _QaCard extends StatelessWidget {
  const _QaCard({required this.seg});

  final QaSegment seg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: () => context.push('/qa/detail', extra: seg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seg.qaTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            _metaLine(seg),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
          ),
          if (seg.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              seg.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (seg.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in seg.tags.take(3))
                  Chip(
                    label: Text(t),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// "2026-02-01 · 01:23:34 · 11:36"(空段自动省略)
  String _metaLine(QaSegment seg) {
    final parts = <String>[
      if (seg.publishedDate != null) qaFormatDate(seg.publishedDate!),
      if (seg.startTime != null) seg.startTime!,
      if (seg.durationSeconds != null) qaFormatDuration(seg.durationSeconds!),
    ];
    return parts.join(' · ');
  }
}
