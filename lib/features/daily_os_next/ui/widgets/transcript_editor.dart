import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TranscriptEditor extends StatelessWidget {
  const TranscriptEditor({
    required this.transcript,
    required this.onChanged,
    this.fieldKey,
    super.key,
  });

  final String transcript;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return TextFormField(
      key: fieldKey,
      initialValue: transcript,
      minLines: 3,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      decoration: InputDecoration(
        labelText: context.messages.dailyOsNextCaptureTranscriptLabel,
        hintText: context.messages.dailyOsNextCaptureTranscriptHint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: tokens.colors.background.level02,
        contentPadding: EdgeInsets.all(tokens.spacing.step4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          borderSide: BorderSide(color: tokens.colors.decorative.level01),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          borderSide: BorderSide(color: tokens.colors.interactive.enabled),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
