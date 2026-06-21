import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';

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
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entry == null) {
      return const SizedBox.shrink();
    }

    // Timestamp metadata: quiet but legible. Sized at bodyMedium (the same step
    // as the card body, up from bodySmall) so it is no longer the smallest line
    // on the card — low-vision and dyslexia users named the date as the hardest
    // line to read. Weight stays regular and the tone stays mediumEmphasis
    // (white @ 80% ≈ 10:1 on the card surface) so the larger size does not make
    // it win first fixation over the bold high-emphasis values, and it clears
    // AA. Proportional figures (no tabular/badge features) so the date reads as
    // one word in the body sans, not a monospaced debug stamp.
    final tokens = context.designTokens;
    final style = tokens.typography.styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.mediumEmphasis,
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
