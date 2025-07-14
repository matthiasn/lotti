import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart';

class EntryDatetimeWidget extends ConsumerWidget {
  const EntryDatetimeWidget({
    required this.entryId,
    this.padding = const EdgeInsets.only(left: 5),
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

    return GestureDetector(
      onTap: () => EntryDateTimeMultiPageModal.show(entry: entry, context: context),
      child: Padding(
        padding: padding,
        child: Text(
          dfShorter.format(entry.meta.dateFrom),
          style: context.textTheme.bodyMedium?.copyWith(
            fontFeatures: [const FontFeature.tabularFigures()],
            color: context.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
