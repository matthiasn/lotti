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

    // Timestamp metadata: the least-important line on the card, so it sits at
    // the smallest type tier (caption, 12) — the same size as the audio
    // timecodes — and never larger than the body, the value, or any other
    // content. mediumEmphasis (white @ 80% ≈ 10:1) keeps it a calm, recessive
    // metadata line; users who need everything bigger use OS text scaling rather
    // than this one element being inflated. Proportional figures (no tabular/
    // badge features) so the date reads as one word in the body sans.
    final tokens = context.designTokens;
    final style = tokens.typography.styles.others.caption.copyWith(
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
