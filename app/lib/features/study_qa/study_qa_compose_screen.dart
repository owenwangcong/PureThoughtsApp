import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import 'study_qa_providers.dart';

/// 新提问页(设计 §4.2):多行输入(≤2000 字)→ 原子 RPC 建线程 → 进入会话页。
/// 待回覆上限(QA_PENDING_LIMIT)显示专属文案;失败时文字保留在输入框。
class StudyQaComposeScreen extends ConsumerStatefulWidget {
  const StudyQaComposeScreen({super.key});

  @override
  ConsumerState<StudyQaComposeScreen> createState() =>
      _StudyQaComposeScreenState();
}

class _StudyQaComposeScreenState extends ConsumerState<StudyQaComposeScreen> {
  final _input = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final text = _input.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final threadId = await createQaThread(text);
      ref.invalidate(qaThreadsProvider);
      if (mounted) context.pushReplacement('/study-qa/$threadId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(qaErrorText(l10n, e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.studyQaAsk)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.studyQaNewHint,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    _input.text.trim().isEmpty || _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(l10n.studyQaSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
