import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_controller.dart';
import 'package:lotti/services/nav_service.dart';

/// The tab root each search surface lives on — where [openRecentSearch]
/// beams to before it puts the query back.
extension RecentSearchSurfaceRoute on RecentSearchSurface {
  String get rootPath => switch (this) {
    RecentSearchSurface.tasks => '/tasks',
    RecentSearchSurface.logbook => '/journal',
    RecentSearchSurface.projects => '/projects',
    RecentSearchSurface.habits => '/habits',
  };
}

/// Runs [search] again: brings its destination's list to the front, then
/// hands the query to the controller that owns that list's search.
///
/// Beams to the tab **root**, not merely to the tab: a tab parked on a detail
/// page would otherwise come forward showing that page, with the search
/// applied to a list the user cannot see.
///
/// The query goes to the same controller method the surface's own field
/// calls, so every field mirrors it back from state the way it mirrors any
/// other external change. That path never passes through the field's
/// `onChanged`, where typed searches are noted, so the reuse is recorded
/// here: running a search again is searching, and it moves back to the top.
void openRecentSearch(
  WidgetRef ref,
  RecentSearch search, {
  required NavService navService,
}) {
  navService.beamToNamed(search.surface.rootPath);
  unawaited(
    ref
        .read(recentSearchesControllerProvider.notifier)
        .record(search.surface, search.query),
  );
  switch (search.surface) {
    case RecentSearchSurface.tasks:
      unawaited(
        ref
            .read(journalPageControllerProvider(true).notifier)
            .setSearchString(search.query),
      );
    case RecentSearchSurface.logbook:
      unawaited(
        ref
            .read(journalPageControllerProvider(false).notifier)
            .setSearchString(search.query),
      );
    case RecentSearchSurface.projects:
      ref
          .read(projectsFilterControllerProvider.notifier)
          .setTextQuery(search.query);
    case RecentSearchSurface.habits:
      // Habits filters only while its search bar is showing; a query set
      // behind a closed bar would change nothing on screen.
      final habits = ref.read(habitsControllerProvider.notifier);
      if (!ref.read(habitsControllerProvider).showSearch) {
        habits.toggleShowSearch();
      }
      habits.setSearchString(search.query);
  }
}
