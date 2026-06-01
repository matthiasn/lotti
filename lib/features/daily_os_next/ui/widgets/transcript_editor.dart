import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    final tokens = context.designTokens;
    final fieldTextStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: tokens.colors.text.highEmphasis.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: TextFormField(
          key: fieldKey,
          initialValue: transcript,
          minLines: lineCount,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          scrollPhysics: const NeverScrollableScrollPhysics(),
          textInputAction: TextInputAction.newline,
          cursorColor: tokens.colors.interactive.enabled,
          style: fieldTextStyle,
          decoration: InputDecoration(
            hintText: context.messages.dailyOsNextCaptureTranscriptHint,
            hintStyle: fieldTextStyle.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
