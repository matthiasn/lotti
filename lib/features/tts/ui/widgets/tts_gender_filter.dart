import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The Female | Male filter over a voice list, on the list rows' text rail.
/// Shared by the on-device voice list and the cloud voice picker, whose
/// voices name their gender as [female] and [male] values of their own type.
///
/// A view filter only: switching it never changes a selection.
class TtsGenderFilter<T> extends StatelessWidget {
  const TtsGenderFilter({
    required this.selected,
    required this.female,
    required this.male,
    required this.onChanged,
    super.key,
  });

  final T selected;
  final T female;
  final T male;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final spacing = context.designTokens.spacing;
    // Its own even space above and below, so it sits the same in every list.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.step5,
        vertical: spacing.step3,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DsSegmentedToggle<T>(
          selected: selected,
          onChanged: onChanged,
          segments: [
            DsSegment(female, messages.speechVoiceGenderFemale),
            DsSegment(male, messages.speechVoiceGenderMale),
          ],
        ),
      ),
    );
  }
}
