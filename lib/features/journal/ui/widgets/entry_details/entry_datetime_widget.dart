import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_modal.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart';

class EntryDatetimeWidget extends ConsumerWidget {
  const EntryDatetimeWidget({
    required this.entryId,
    super.key,
  });

  final String entryId;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: TextButton(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            builder: (BuildContext _) {
              return EntryDateTimeModal(item: entry);
            },
          );
        },
        child: Text(
          dfShorter.format(entry.meta.dateFrom),
          style: monospaceTextStyle.copyWith(
            color: context.textTheme.bodyMedium?.color ?? Colors.grey,
          ),
        ),
      ),
    );
  }
}
