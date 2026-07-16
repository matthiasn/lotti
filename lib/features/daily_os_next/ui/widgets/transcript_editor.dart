import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TranscriptEditor extends StatelessWidget {
  const TranscriptEditor({
    required this.transcript,
    required this.onChanged,
    this.lineCount = 4,
    this.fieldKey,
    super.key,
  });

  final String transcript;
  final ValueChanged<String> onChanged;

  /// Minimum number of rows to reserve before the editor grows with content.
  final int lineCount;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return DesignSystemTextarea(
      initialValue: transcript,
      fieldKey: fieldKey,
      size: DesignSystemTextareaSize.small,
      label: context.messages.dailyOsNextCaptureTranscriptLabel,
      hintText: context.messages.dailyOsNextCaptureTranscriptHint,
      minLines: lineCount,
      growWithContent: true,
      onChanged: onChanged,
    );
  }
}
