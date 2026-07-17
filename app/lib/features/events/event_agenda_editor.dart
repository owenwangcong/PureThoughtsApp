import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import 'event_detail_models.dart';
import 'events_providers.dart';

/// 管理员时间表/资料编辑器(设计 event-agenda.md §6.2)。
/// 时间表:本地编辑一批行,「儲存」一次性提交(删旧插新,sort_order 按时间重排)。
/// 资料:PDF 即时上传/删除(经 Supabase Storage `event-files`,§6.3 删对象再删行)。
/// 循环活动仅第 1 天有意义(§12.4),隐藏「第幾天」控件、写库恒 day_index=1。
class EventAgendaEditorScreen extends ConsumerStatefulWidget {
  const EventAgendaEditorScreen({super.key, this.event});

  final Map<String, dynamic>? event;

  @override
  ConsumerState<EventAgendaEditorScreen> createState() =>
      _EventAgendaEditorScreenState();
}

/// 本地可变行(编辑期间不落库,「儲存」时整批写入)。
class _Row {
  _Row({
    required this.day,
    required this.start,
    required this.activity,
    this.end,
    this.linkUrl,
    this.linkLabel,
  });

  int day;
  String start; // "HH:mm"
  String? end; // "HH:mm"
  String activity;
  String? linkUrl;
  String? linkLabel;

  factory _Row.from(AgendaItem a) => _Row(
        day: a.dayIndex,
        start: a.startTime,
        end: a.endTime,
        activity: a.activity,
        linkUrl: a.linkUrl,
        linkLabel: a.linkLabel,
      );

  String get timeRange => end == null ? start : '$start–$end';
}

class _EventAgendaEditorScreenState
    extends ConsumerState<EventAgendaEditorScreen> {
  List<_Row> _rows = [];
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  Map<String, dynamic> get _event => widget.event ?? const {};
  String get _eventId => _event['id'] as String? ?? '';
  bool get _recurring =>
      (_event['recurrence_rule'] as String?)?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(agendaItemsProvider(_eventId).future);
      if (!mounted) return;
      setState(() {
        _rows = items.map(_Row.from).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_Row> get _sorted {
    final l = [..._rows];
    l.sort((a, b) {
      final c = a.day.compareTo(b.day);
      if (c != 0) return c;
      final t = a.start.compareTo(b.start);
      return t != 0 ? t : a.activity.compareTo(b.activity);
    });
    return l;
  }

  int get _maxDay =>
      _rows.isEmpty ? 1 : _rows.map((r) => r.day).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_event.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.eventEditAgenda)),
        body: EmptyState(icon: Icons.event_busy, title: l10n.emptyList),
      );
    }
    final attAsync = ref.watch(attachmentsProvider(_eventId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.eventEditAgenda),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              tooltip: l10n.save,
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveAgenda,
            ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ---- 時間表 ----
                SectionHeader(l10n.eventAgendaTitle),
                if (_rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(l10n.eventNoAgenda,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                else
                  for (final r in _sorted) _rowTile(r, l10n),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.eventAddAgendaRow),
                    onPressed: () => _editRow(),
                  ),
                ),

                const Divider(height: 40),

                // ---- 相關資料(PDF)----
                SectionHeader(l10n.eventAttachmentsTitle),
                attAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ErrorRetry(
                        onRetry: () =>
                            ref.invalidate(attachmentsProvider(_eventId))),
                  ),
                  data: (atts) => Column(
                    children: [
                      for (final a in atts)
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: Text(a.title),
                          subtitle: a.sizeText.isEmpty ? null : Text(a.sizeText),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error),
                            onPressed: () => _deleteAttachment(a),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: FilledButton.tonalIcon(
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file),
                    label: Text(
                        _uploading ? l10n.eventUploading : l10n.eventUploadPdf),
                    onPressed: _uploading ? null : _uploadPdf,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _rowTile(_Row r, AppLocalizations l10n) {
    final subtitle = <String>[
      if (!_recurring) '第${cnNumber(r.day)}天',
      if (r.linkUrl != null) (r.linkLabel?.isNotEmpty == true ? r.linkLabel! : r.linkUrl!),
    ].join(' · ');
    return ListTile(
      leading: SizedBox(
        width: 88,
        child: Text(r.timeRange,
            style: Theme.of(context).textTheme.bodyMedium),
      ),
      title: Text(r.activity),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editRow(existing: r),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            onPressed: () => setState(() => _rows.remove(r)),
          ),
        ],
      ),
      onTap: () => _editRow(existing: r),
    );
  }

  Future<void> _editRow({_Row? existing}) async {
    final l10n = AppLocalizations.of(context);
    var day = existing?.day ?? 1;
    var start = existing?.start ?? '';
    String? end = existing?.end;
    final activity = TextEditingController(text: existing?.activity ?? '');
    final linkUrl = TextEditingController(text: existing?.linkUrl ?? '');
    final linkLabel = TextEditingController(text: existing?.linkLabel ?? '');
    final maxDay = _maxDay + 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> pickStart() async {
            final t = await showTimePicker(
                context: context, initialTime: _parse(start) ?? TimeOfDay.now());
            if (t != null) setLocal(() => start = _fmt(t));
          }

          Future<void> pickEnd() async {
            final t = await showTimePicker(
                context: context,
                initialTime: _parse(end) ?? _parse(start) ?? TimeOfDay.now());
            if (t != null) setLocal(() => end = _fmt(t));
          }

          return AlertDialog(
            title: Text(existing == null ? l10n.eventAddAgendaRow : l10n.edit),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_recurring) ...[
                    Row(
                      children: [
                        Text(l10n.agendaDay),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed:
                              day > 1 ? () => setLocal(() => day--) : null,
                        ),
                        Text('$day', style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: day < maxDay
                              ? () => setLocal(() => day++)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(start.isEmpty ? l10n.agendaStart : start),
                    onPressed: pickStart,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(end == null ? l10n.agendaEnd : end!),
                          onPressed: pickEnd,
                        ),
                      ),
                      if (end != null)
                        IconButton(
                          tooltip: l10n.cancel,
                          icon: const Icon(Icons.clear),
                          onPressed: () => setLocal(() => end = null),
                        ),
                    ],
                  ),
                  TextField(
                    controller: activity,
                    decoration: InputDecoration(labelText: l10n.agendaActivity),
                  ),
                  TextField(
                    controller: linkUrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(labelText: l10n.agendaLinkUrl),
                  ),
                  TextField(
                    controller: linkLabel,
                    decoration: InputDecoration(labelText: l10n.agendaLinkLabel),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.submit)),
            ],
          );
        },
      ),
    );
    if (ok != true || start.isEmpty || activity.text.trim().isEmpty) return;

    final url = linkUrl.text.trim();
    final label = linkLabel.text.trim();
    setState(() {
      final target = existing ?? _Row(day: day, start: start, activity: '');
      target
        ..day = _recurring ? 1 : day
        ..start = start
        ..end = end
        ..activity = activity.text.trim()
        ..linkUrl = url.isEmpty ? null : url
        ..linkLabel = label.isEmpty ? null : label;
      if (existing == null) _rows.add(target);
    });
  }

  Future<void> _saveAgenda() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      await client.from('event_agenda_items').delete().eq('event_id', _eventId);
      final sorted = _sorted;
      if (sorted.isNotEmpty) {
        await client.from('event_agenda_items').insert([
          for (var i = 0; i < sorted.length; i++)
            {
              'event_id': _eventId,
              'day_index': _recurring ? 1 : sorted[i].day,
              'start_time': sorted[i].start,
              'end_time': sorted[i].end,
              'activity': sorted[i].activity,
              'link_url': sorted[i].linkUrl,
              'link_label': sorted[i].linkLabel,
              'sort_order': i,
            },
        ]);
      }
      ref.invalidate(agendaItemsProvider(_eventId));
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventAgendaSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadPdf() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
      return;
    }
    final defaultTitle =
        f.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    if (!mounted) return;
    final title = await _askTitle(defaultTitle);
    if (title == null || title.trim().isEmpty) return;

    setState(() => _uploading = true);
    try {
      final client = Supabase.instance.client;
      final path = '$_eventId/${DateTime.now().microsecondsSinceEpoch}.pdf';
      await client.storage.from('event-files').uploadBinary(path, bytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'));
      final count = ref.read(attachmentsProvider(_eventId)).value?.length ?? 0;
      await client.from('event_attachments').insert({
        'event_id': _eventId,
        'title': title.trim(),
        'storage_path': path,
        'size_bytes': bytes.length,
        'content_type': 'application/pdf',
        'sort_order': count,
      });
      ref.invalidate(attachmentsProvider(_eventId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _askTitle(String initial) {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.eventAttachmentName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.eventAttachmentName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: Text(l10n.eventUploadPdf)),
        ],
      ),
    );
  }

  Future<void> _deleteAttachment(EventAttachment a) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        content: Text(l10n.confirmDeleteAttachment),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final client = Supabase.instance.client;
      // §6.3:先删 Storage 对象,再删行
      await client.storage.from('event-files').remove([a.storagePath]);
      await client.from('event_attachments').delete().eq('id', a.id);
      ref.invalidate(attachmentsProvider(_eventId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }
}

TimeOfDay? _parse(String? hhmm) {
  if (hhmm == null || hhmm.length < 4) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
