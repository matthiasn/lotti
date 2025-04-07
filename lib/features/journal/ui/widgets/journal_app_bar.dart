import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class JournalSliverAppBar extends ConsumerWidget {
  const JournalSliverAppBar({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      leadingWidth: 100,
      leading: const BackWidget(),
      pinned: true,
      actions: [
        SaveButton(entryId: entryId),
      ],
      automaticallyImplyLeading: false,
    );
  }
}
