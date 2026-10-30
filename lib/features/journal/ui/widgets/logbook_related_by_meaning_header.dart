import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The heading over the logbook entries a search found by meaning rather
/// than by its words. They follow the word matches (ADR 0149), so the
/// heading marks where the exact matches end.
class LogbookRelatedByMeaningHeader extends StatelessWidget {
  const LogbookRelatedByMeaningHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step3,
      ),
      child: Text(
        context.messages.searchRelatedByMeaningSection,
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
