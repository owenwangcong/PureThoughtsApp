import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/channels.dart';
import '../../core/settings.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import 'live_providers.dart';
import 'webex.dart';

/// 直播(PRD §6):YouTube 开播检测 + App 内观看;Webex 固定房间一键加入;
/// 往期回看(media_items)。匿名可用。
/// ⚠️ 大陆用户 YouTube/Webex 需自备网络条件(PRD §14.2)。
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final live = ref.watch(currentLiveProvider);
    final replays = ref.watch(replayVideosProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentLiveProvider);
          ref.invalidate(replayVideosProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- YouTube ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: live.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) =>
                      ErrorRetry(onRetry: () => ref.invalidate(currentLiveProvider)),
                  data: (stream) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill,
                              size: 32,
                              color: stream != null ? scheme.error : scheme.outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('YouTube',
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                          if (stream != null)
                            Chip(
                              label: Text(l10n.liveNow,
                                  style: TextStyle(color: scheme.onError)),
                              backgroundColor: scheme.error,
                              side: BorderSide.none,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (stream != null) ...[
                        if (stream['title'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(stream['title'] as String),
                          ),
                        FilledButton.icon(
                          icon: const Icon(Icons.live_tv),
                          label: Text(l10n.enterLive),
                          onPressed: () =>
                              context.push('/watch/${stream['video_id']}'),
                        ),
                      ] else ...[
                        Text(l10n.notLive,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.language),
                          label: Text(l10n.openChannel),
                          // 应用内浏览器打开频道页,不离开 App
                          onPressed: () => context.push(Uri(
                            path: '/webview',
                            queryParameters: {
                              'url': Channels.youtubeChannelUrl,
                              'title': 'YouTube',
                            },
                          ).toString()),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Webex(固定房间,无状态检测;以日历预告为准) ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.videocam, size: 32, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Webex',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.webexHint,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.login),
                      label: Text(l10n.joinWebex),
                      // 应用内加入(网页客户端全自动:填链接/名字/邮箱并加入)
                      onPressed: () => openWebexInApp(context, ref,
                          url: Channels.webexBrowserJoinUrl),
                    ),
                    // 永远保留 Webex App 选项(用户定案)
                    TextButton.icon(
                      icon: const Icon(Icons.exit_to_app),
                      label: Text(l10n.webexOpenApp),
                      onPressed: () => launchUrl(Uri.parse(Channels.webexJoinUrl),
                          mode: LaunchMode.externalApplication),
                    ),
                  ],
                ),
              ),
            ),

            // ---- 往期回看 ----
            replays.maybeWhen(
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(l10n.replaysTitle,
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 4)),
                        for (final v in list)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.ondemand_video),
                            title: Text((locale.scriptCode == 'Hans'
                                ? v['title_hans']
                                : v['title_hant']) as String),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final id = youtubeVideoId(v['url'] as String);
                              if (id != null) {
                                context.push('/watch/$id');
                              } else {
                                context.push(Uri(
                                  path: '/webview',
                                  queryParameters: {'url': v['url'] as String},
                                ).toString());
                              }
                            },
                          ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
