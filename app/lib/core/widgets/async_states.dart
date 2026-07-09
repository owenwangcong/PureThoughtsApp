import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// 异步状态的统一表现(PRD v0.5.4 §11):
/// 加载用骨架屏、空态给引导与动作、错误必带重试 —— 不用裸转圈/裸文案。

/// 引导式空态:图标 + 标题 + 引导文案 + 可选动作
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// 错误态:说明 + 重试
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: l10n.loadFailed,
      action: FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
    );
  }
}

/// 列表骨架屏(轻脉动,替代整页转圈)
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 6, this.rowHeight = 64});

  final int rows;
  final double rowHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return FadeTransition(
      opacity: _controller,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: widget.rows,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 区块标题(金色小标,统一分组视觉)
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.padding});

  final String title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
