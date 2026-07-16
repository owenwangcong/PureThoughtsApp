import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import 'qa_models.dart';
import 'qa_providers.dart';

/// 问答详情页(PRD §6 / design/qa-search.md §7.3):播放器为主、摘要正文在下。
/// 受 YouTube 嵌入限制(错误 153),播放形态 = 封面 + 大播放按钮 → 全屏 /watch 页;
/// **摘要正文与播放是否可用无关,永远完整渲染**(大陆用户拿到的全部价值)。
/// 上游无按 id 取单条接口,详情只能经 extra 传对象;冷启动无 extra → 友好兜底。
class QaDetailScreen extends ConsumerWidget {
  const QaDetailScreen({super.key, this.segment});

  final QaSegment? segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final seg = segment;
    if (seg == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off,
          title: l10n.qaEmpty,
          action: FilledButton.tonal(
            onPressed: () => context.canPop() ? context.pop() : context.go('/qa'),
            child: Text(l10n.qaBackToList),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Cover(seg: seg, onPlay: () => _openPlayer(context, seg)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seg.qaTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  _metaLine(context, seg),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 16),
                if (seg.summary.isNotEmpty)
                  SelectableText(seg.summary, style: theme.textTheme.bodyLarge),
                if (seg.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final t in seg.tags)
                        ActionChip(
                          label: Text(t),
                          onPressed: () => _searchByTag(context, ref, t),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.qaOpenExternal),
                    onPressed: () => launchUrl(
                      Uri.parse(seg.timestampUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine(BuildContext context, QaSegment seg) {
    final l10n = AppLocalizations.of(context);
    return <String>[
      if (seg.publishedDate != null) qaFormatDate(seg.publishedDate!),
      if (seg.videoTitle.isNotEmpty) l10n.qaFromVideo(seg.videoTitle),
      if (seg.durationSeconds != null) qaFormatDuration(seg.durationSeconds!),
    ].join(' · ');
  }

  /// 以该标签搜索:把全局搜索条件设为该单标签,返回列表页即呈现结果。
  void _searchByTag(BuildContext context, WidgetRef ref, String tag) {
    ref.read(qaSearchProvider.notifier).setTags([tag]);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/qa');
    }
  }

  void _openPlayer(BuildContext context, QaSegment seg) {
    final vid = seg.videoId;
    if (vid == null) {
      launchUrl(Uri.parse(seg.timestampUrl), mode: LaunchMode.externalApplication);
      return;
    }
    final sec = seg.startSeconds;
    final loc = sec == null
        ? '/watch/$vid'
        : Uri(path: '/watch/$vid', queryParameters: {'t': '$sec'}).toString();
    context.push(loc);
  }
}

/// 16:9 封面:YouTube 缩略图 + 中央大播放按钮 + 右下角时间戳。
/// i.ytimg.com 在大陆同样被墙 → errorBuilder 降级主题色块,播放功能不变、不留破图。
class _Cover extends StatelessWidget {
  const _Cover({required this.seg, required this.onPlay});

  final QaSegment seg;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vid = seg.videoId;
    // 以 16:9 为基准,但在大屏/横屏(如平板)限高,
    // 免得封面占满整屏把摘要挤到折叠线以下(摘要是核心价值,§7.3)。
    final size = MediaQuery.sizeOf(context);
    final coverHeight = math.min(size.width * 9 / 16, size.height * 0.4);
    return GestureDetector(
      onTap: onPlay,
      child: SizedBox(
        height: coverHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (vid != null)
              Image.network(
                'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(scheme),
              )
            else
              _fallback(scheme),
            Container(color: Colors.black.withValues(alpha: 0.15)),
            const Center(
              child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
            ),
            if (seg.startTime != null)
              PositionedDirectional(
                end: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    seg.startTime!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) =>
      ColoredBox(color: scheme.surfaceContainerHigh);
}
