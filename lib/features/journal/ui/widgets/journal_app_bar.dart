import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

/// Pinned sliver app bar for the entry detail page: an optional back button
/// and the entry's [SaveButton] (which fades in only when there are unsaved
/// changes).
///
/// [showBackButton] is false in the desktop split pane, where the logbook list
/// stays on screen next to the details and a back chevron would point nowhere.
class JournalSliverAppBar extends ConsumerWidget {
  const JournalSliverAppBar({
    required this.entryId,
    this.showBackButton = true,
    super.key,
  });

  final String entryId;
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      leadingWidth: showBackButton ? 100 : 0,
      leading: showBackButton ? const BackWidget() : null,
      pinned: true,
      // Match the unified logbook canvas rather than the Material default, so
      // the pinned bar does not band against the page as content scrolls
      // under it.
      backgroundColor: dsPageSurface(context),
      surfaceTintColor: Colors.transparent,
      actions: [
        SaveButton(entryId: entryId),
      ],
      automaticallyImplyLeading: false,
    );
  }
}
