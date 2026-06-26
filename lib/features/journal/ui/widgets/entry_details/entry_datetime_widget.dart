import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

class EntryDatetimeWidget extends ConsumerWidget {
  const EntryDatetimeWidget({
    required this.entryId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String entryId;
  final EdgeInsets padding;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entry == null) {
      return const SizedBox.shrink();
    }

    // Timestamp metadata: the least-important line on the card, so it sits at
    // the smallest type tier (caption, 12) AND the quietest text tone
    // (lowEmphasis ≈ 6:1 — still above the 4.5:1 AA floor) so it recedes to the
    // bottom of the visual hierarchy, never competing with the value, body, or
    // even the timecodes. It is never larger than any content; users who need
    // everything bigger use OS text scaling rather than this one element being
    // inflated. Shared numeric badge features (tabular + open four/six/nine +
    // slashed zero) keep the date digits steady and legible at this small size.
    final tokens = context.designTokens;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

    return GestureDetector(
      onTap: () =>
          EntryDateTimeMultiPageModal.show(entry: entry, context: context),
      child: Padding(
        padding: padding,
        child: Text(
          dfShorter.format(entry.meta.dateFrom),
          style: style,
        ),
      ),
    );
  }
}
