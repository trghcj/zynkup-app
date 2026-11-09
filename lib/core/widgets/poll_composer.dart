import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

// Limits match the backend (zynkup_backend/app/validation.py).
const int kPollMaxQuestion = 300;
const int kPollMaxOption = 100;
const int kPollMinOptions = 2;
const int kPollMaxOptions = 10;

/// A poll the user has written but not sent yet.
class PollDraft {
  final String question;
  final List<String> options;

  const PollDraft({required this.question, required this.options});

  Map<String, dynamic> toJson() => {'question': question, 'options': options};
}

/// Returns an error message for an invalid poll, or null when it is valid.
/// Blank options are ignored, as they are on the server.
String? validatePoll(String question, List<String> options) {
  final q = question.trim();
  if (q.isEmpty) return 'Add a question for your poll';
  if (q.length > kPollMaxQuestion) {
    return 'The question must be at most $kPollMaxQuestion characters';
  }
  final cleaned =
      options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
  if (cleaned.length < kPollMinOptions) {
    return 'Add at least $kPollMinOptions options';
  }
  if (cleaned.length > kPollMaxOptions) {
    return 'A poll can have at most $kPollMaxOptions options';
  }
  if (cleaned.any((o) => o.length > kPollMaxOption)) {
    return 'Each option must be at most $kPollMaxOption characters';
  }
  if (cleaned.map((o) => o.toLowerCase()).toSet().length != cleaned.length) {
    return 'Options must be different from each other';
  }
  return null;
}

/// Opens a bottom sheet to write a poll. Returns the poll, or null if the
/// user closed the sheet. Pass [initial] to edit an existing draft.
Future<PollDraft?> showPollComposer(
  BuildContext context, {
  PollDraft? initial,
  String submitLabel = 'Done',
}) {
  return showModalBottomSheet<PollDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ZynkRadius.lg)),
    ),
    builder: (_) => _PollComposerSheet(initial: initial, submitLabel: submitLabel),
  );
}

class _PollComposerSheet extends StatefulWidget {
  final PollDraft? initial;
  final String submitLabel;

  const _PollComposerSheet({this.initial, required this.submitLabel});

  @override
  State<_PollComposerSheet> createState() => _PollComposerSheetState();
}

class _PollComposerSheetState extends State<_PollComposerSheet> {
  late final TextEditingController _question;
  late final List<TextEditingController> _options;
  String? _error;

  @override
  void initState() {
    super.initState();
    _question = TextEditingController(text: widget.initial?.question ?? '');
    final initialOptions = widget.initial?.options ?? const <String>[];
    _options = [
      for (final o in initialOptions) TextEditingController(text: o),
    ];
    while (_options.length < kPollMinOptions) {
      _options.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= kPollMaxOptions) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= kPollMinOptions) return;
    setState(() => _options.removeAt(index).dispose());
  }

  void _submit() {
    final options = _options.map((c) => c.text).toList();
    final error = validatePoll(_question.text, options);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      PollDraft(
        question: _question.text.trim(),
        options: options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList(),
      ),
    );
  }

  InputDecoration _decoration(BuildContext context, String hint) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45), fontSize: 14),
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.poll_rounded, color: ZynkColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      widget.initial == null ? 'Create a poll' : 'Edit poll',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('poll_question'),
                  controller: _question,
                  maxLength: kPollMaxQuestion,
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                  decoration: _decoration(context, 'Ask a question...'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Options',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: Key('poll_option_$i'),
                            controller: _options[i],
                            maxLength: kPollMaxOption,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(color: scheme.onSurface),
                            decoration: _decoration(context, 'Option ${i + 1}'),
                          ),
                        ),
                        if (_options.length > kPollMinOptions)
                          IconButton(
                            tooltip: 'Remove option',
                            icon: Icon(Icons.close_rounded,
                                size: 20, color: scheme.onSurface.withValues(alpha: 0.55)),
                            onPressed: () => _removeOption(i),
                          ),
                      ],
                    ),
                  ),
                if (_options.length < kPollMaxOptions)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add option'),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: const TextStyle(color: ZynkColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('poll_submit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ZynkColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.md)),
                  ),
                  onPressed: _submit,
                  child: Text(widget.submitLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
