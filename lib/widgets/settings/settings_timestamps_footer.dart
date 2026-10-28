import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:material_ui/material_ui.dart';

/// When a definition was created and last modified, as one quiet group at the
/// very end of its settings editor.
///
/// Bookkeeping rather than something to edit, so it sits below the form and
/// Delete in the low-emphasis caption style, both lines tight together. Each
/// timestamp is written in the device's own date and clock conventions
/// ([deviceTimestampLabel]).
///
/// Either timestamp may be null — a definition still being created has
/// neither — and a missing one simply leaves its line out; with both missing
/// the footer renders nothing at all.
class SettingsTimestampsFooter extends StatelessWidget {
  const SettingsTimestampsFooter({
    required this.createdAt,
    required this.updatedAt,
    super.key,
  });

  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final created = createdAt;
    final updated = updatedAt;
    if (created == null && updated == null) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final messages = context.messages;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step6,
        bottom: tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: tokens.spacing.step1,
        children: [
          if (created != null)
            Text(
              messages.settingsDefinitionCreatedAt(
                deviceTimestampLabel(context, created),
              ),
              style: style,
            ),
          if (updated != null)
            Text(
              messages.settingsDefinitionUpdatedAt(
                deviceTimestampLabel(context, updated),
              ),
              style: style,
            ),
        ],
      ),
    );
  }
}
