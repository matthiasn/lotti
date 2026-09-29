import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The Recents controller a search field feeds, or null where no Recents
/// list is shown.
///
/// Recents live in the mobile sidebar drawer, which exists only on a compact
/// window. The desktop layout neither shows the list nor offers to clear it,
/// so a search run there is not remembered at all rather than piling up in a
/// history the user never sees.
///
/// Call it at the moment of the search, not while building: the answer
/// follows the window's current width, and the controller is only created
/// once a search is actually typed on a compact window.
RecentSearchesController? recentSearchRecorder(
  BuildContext context,
  WidgetRef ref,
) => isDesktopLayout(context)
    ? null
    : ref.read(recentSearchesControllerProvider.notifier);
