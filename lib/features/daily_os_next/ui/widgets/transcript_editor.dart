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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.messages.dailyOsNextCaptureTranscriptLabel,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        TextFormField(
          key: fieldKey,
          initialValue: transcript,
          minLines: 3,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
          decoration: InputDecoration(
            hintText: context.messages.dailyOsNextCaptureTranscriptHint,
            filled: true,
            fillColor: tokens.colors.background.level02.withValues(alpha: 0.54),
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              borderSide: BorderSide(
                color: tokens.colors.decorative.level01.withValues(alpha: 0.72),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              borderSide: BorderSide(color: tokens.colors.interactive.enabled),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
