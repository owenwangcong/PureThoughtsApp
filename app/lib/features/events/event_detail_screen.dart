import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../core/settings.dart';
import '../../core/timezones.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../live/webex.dart';
import 'event_detail_models.dart';
import 'event_edit.dart';
import 'events_providers.dart';
import 'occurrence_utils.dart';

/// 活动详情整页(PRD v0.5.12 §5,设计 event-agenda.md §6.1):
/// 取代原 bottom sheet —— 简介 + 时间表(按天分组、行内经文链接) + 相关资料(PDF 下载)
/// + YouTube/Webex + 管理员操作;右上角「分享」把整张时间表转成纯文本发 Line/微信。
/// 经 go_router `extra` 传 Occurrence;冷启动无 extra → 回日历(同 QA 详情做法)。
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, this.occ});

  final Occurrence? occ;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final o = occ;
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.event_busy,
          title: l10n.emptyList,
          action: FilledButton.tonal(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/calendar'),
            child: Text(l10n.calendarTitle),
          ),
        ),
      );
    }

    final hans = ref.watch(localeProvider).scriptCode == 'Hans';
    final isAdmin = ref.watch(myProfileProvider).value?['is_app_admin'] == true;
    final eventId = o.event['id'] as String;
    final agendaAsync = ref.watch(agendaItemsProvider(eventId));
    final attAsync = ref.watch(attachmentsProvider(eventId));

    final when = DateFormat('yyyy-MM-dd HH:mm').format(o.startAt);
    final dur = o.event['duration_minutes'];
    final whenText = dur != null ? '$when · $dur ${l10n.unitMinute}' : when;
    final firstDayDate = DateTime(o.startAt.year, o.startAt.month, o.startAt.day);

    // 活动当地时间加注(PRD v0.5.15 §5):活动时区的墙钟与设备显示不同才显示
    final tzName = o.event['timezone'] as String? ?? 'Asia/Shanghai';
    final evLocal = tz.TZDateTime.from(o.startAt, locationOf(tzName));
    final sameWall = evLocal.day == o.startAt.day &&
        evLocal.hour == o.startAt.hour &&
        evLocal.minute == o.startAt.minute;
    final localTimeNote = sameWall
        ? null
        : '${l10n.eventLocalTime}:'
            '${DateFormat('MM-dd HH:mm').format(DateTime(evLocal.year, evLocal.month, evLocal.day, evLocal.hour, evLocal.minute))}'
            '(${tzLabel(tzName, hans: hans)})';

    return Scaffold(
      appBar: AppBar(
        title: Text(o.event['title'] as String),
        actions: [
          IconButton(
            tooltip: l10n.eventShare,
            icon: const Icon(Icons.ios_share),
            onPressed: () => _share(
              o: o,
              whenText: whenText,
              agenda: agendaAsync.value ?? const [],
              attachments: attAsync.value ?? const [],
              hans: hans,
              firstDayDate: firstDayDate,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.event['title'] as String,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  o.cancelled ? '$whenText · ${l10n.eventCancelled}' : whenText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (localTimeNote != null)
                  Text(
                    localTimeNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                if (o.event['content'] != null) ...[
                  const SizedBox(height: 12),
                  Text(o.event['content'] as String),
                ],
              ],
            ),
          ),

          // ---- 時間表 ----
          agendaAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ErrorRetry(
                  onRetry: () => ref.invalidate(agendaItemsProvider(eventId))),
            ),
            data: (items) => _AgendaView(
              items: items,
              title: l10n.eventAgendaTitle,
              copyLabel: l10n.eventCopy,
              firstDayDate: firstDayDate,
              defaultLinkLabel: l10n.eventLinkLabelDefault,
              onCopy: () => _copy(
                context,
                l10n,
                renderAgendaText(
                  title: o.event['title'] as String,
                  whenText: whenText,
                  agenda: items,
                  attachments: attAsync.value ?? const [],
                  youtubeUrl: o.event['youtube_url'] as String?,
                  hans: hans,
                  firstDayDate: firstDayDate,
                ),
              ),
            ),
          ),

          // ---- 相關資料 ----
          attAsync.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            data: (atts) => atts.isEmpty
                ? const SizedBox.shrink()
                : _AttachmentView(
                    atts: atts, title: l10n.eventAttachmentsTitle),
          ),

          // ---- 直播/會議入口 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (o.event['youtube_url'] != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('YouTube'),
                    onPressed: () => _openYoutube(
                        context, o.event['youtube_url'] as String),
                  ),
                if (o.event['webex_url'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Webex'),
                          onPressed: () => openWebexInApp(context, ref,
                              url: o.event['webex_url'] as String),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.webexOpenApp,
                        icon: const Icon(Icons.exit_to_app),
                        onPressed: () => launchUrl(
                            Uri.parse(o.event['webex_url'] as String),
                            mode: LaunchMode.externalApplication),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ---- 管理員 ----
          if (isAdmin) _adminActions(context, ref, o, l10n),
        ],
      ),
    );
  }

  Widget _adminActions(BuildContext context, WidgetRef ref, Occurrence o,
      AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 40),
        SectionHeader(l10n.eventAdminTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await showEventEditor(context, ref, existing: o.event);
                        if (context.mounted) {
                          context.canPop() ? context.pop() : context.go('/calendar');
                        }
                      },
                      child: Text(l10n.editEvent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/calendar/event/agenda',
                          extra: o.event),
                      child: Text(l10n.eventEditAgenda),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!o.cancelled)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelOccurrence(context, ref, o),
                        child: Text(l10n.cancelOccurrence),
                      ),
                    ),
                  if (!o.cancelled) const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: () => _deleteEvent(context, ref, o),
                      child: Text(l10n.deleteEvent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openYoutube(BuildContext context, String url) {
    final id = RegExp(r'(?:v=|youtu\.be/|/live/)([\w-]{11})')
        .firstMatch(url)
        ?.group(1);
    context.push(id != null
        ? '/watch/$id'
        : Uri(path: '/webview', queryParameters: {
            'url': url,
            'title': 'YouTube',
          }).toString());
  }

  Future<void> _cancelOccurrence(
      BuildContext context, WidgetRef ref, Occurrence o) async {
    await Supabase.instance.client.from('event_overrides').upsert({
      'event_id': o.event['id'],
      'occurrence_date': o.dateKey,
      'patch': {'cancelled': true},
    }, onConflict: 'event_id,occurrence_date');
    invalidateEvents(ref);
    if (context.mounted) {
      context.canPop() ? context.pop() : context.go('/calendar');
    }
  }

  Future<void> _deleteEvent(
      BuildContext context, WidgetRef ref, Occurrence o) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        content: Text(l10n.confirmDeleteEvent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(l10n.submit)),
        ],
      ),
    );
    if (ok != true) return;
    final client = Supabase.instance.client;
    final eventId = o.event['id'] as String;
    // §6.3:先删 Storage 对象(级联不会清对象),再删活动(级联清子表行)
    final atts = await client
        .from('event_attachments')
        .select('storage_path')
        .eq('event_id', eventId);
    final paths = [for (final r in atts) r['storage_path'] as String];
    if (paths.isNotEmpty) {
      await client.storage.from('event-files').remove(paths);
    }
    await client.from('events').delete().eq('id', eventId);
    invalidateEvents(ref);
    if (context.mounted) {
      context.canPop() ? context.pop() : context.go('/calendar');
    }
  }

  Future<void> _share({
    required Occurrence o,
    required String whenText,
    required List<AgendaItem> agenda,
    required List<EventAttachment> attachments,
    required bool hans,
    required DateTime firstDayDate,
  }) async {
    final text = renderAgendaText(
      title: o.event['title'] as String,
      whenText: whenText,
      agenda: agenda,
      attachments: attachments,
      youtubeUrl: o.event['youtube_url'] as String?,
      hans: hans,
      firstDayDate: firstDayDate,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _copy(BuildContext context, AppLocalizations l10n, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.eventCopied)));
  }
}

/// 时间表视图:按天分组,单日不出「第N天」头;行内可选经文链接。
class _AgendaView extends StatelessWidget {
  const _AgendaView({
    required this.items,
    required this.title,
    required this.copyLabel,
    required this.firstDayDate,
    required this.defaultLinkLabel,
    required this.onCopy,
  });

  final List<AgendaItem> items;
  final String title;
  final String copyLabel;
  final DateTime firstDayDate;
  final String defaultLinkLabel;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final grouped = groupAgendaByDay(items);
    final multiDay = grouped.length > 1;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title)),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: Text(copyLabel),
                onPressed: onCopy,
              ),
            ),
          ],
        ),
        for (final g in grouped) ...[
          if (multiDay)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                dayLabel(g.day, firstDayDate: firstDayDate),
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          for (final it in g.items)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间列:随字号缩放的固定宽(跨行对齐);默认字号比原 96 窄,
                  // 把宽度让给活动内容列,尽量不换行;大字号下等比放宽,时间自身也不折行
                  SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(80),
                    child: Text(it.timeRange, style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text(it.activity)),
                  if (it.linkUrl != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(it.linkLabel?.isNotEmpty == true
                          ? it.linkLabel!
                          : defaultLinkLabel),
                      onPressed: () => launchUrl(Uri.parse(it.linkUrl!),
                          mode: LaunchMode.externalApplication),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// 相关资料:PDF 列表,点整行/下载图标 → 打开公开 URL(浏览器下载/预览)。
class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.atts, required this.title});

  final List<EventAttachment> atts;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        for (final a in atts)
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(a.title),
            subtitle: a.sizeText.isEmpty ? null : Text(a.sizeText),
            trailing: const Icon(Icons.download_outlined),
            onTap: () => launchUrl(Uri.parse(a.publicUrl),
                mode: LaunchMode.externalApplication),
          ),
      ],
    );
  }
}
