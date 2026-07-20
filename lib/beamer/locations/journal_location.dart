import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/pages/journal_root_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/uuid.dart';

class JournalLocation extends BeamLocation<BeamState> {
  JournalLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/journal',
    '/journal/:entryId',
    '/journal/fill_survey/:surveyType',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final rawEntryId = state.pathParameters['entryId'];
    // `/journal/:entryId` also greedily matches the `fill_survey` segment, so
    // only a real uuid counts as an entry selection.
    final entryId = isUuid(rawEntryId) ? rawEntryId : null;
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    if (isDesktop) {
      // Writing during build would mutate a notifier other widgets are already
      // listening to in this frame; defer to the next microtask. Guarded
      // against the service being replaced/disposed in the meantime (tests
      // reset getIt between cases).
      scheduleMicrotask(() {
        if (getIt.isRegistered<NavService>() &&
            identical(getIt<NavService>(), navService)) {
          navService.desktopSelectedEntryId.value = entryId;
        }
      });
    }

    return [
      const BeamPage(
        key: ValueKey('journal'),
        title: 'Journal',
        child: JournalRootPage(),
      ),
      if (!isDesktop && entryId != null)
        BeamPage(
          key: ValueKey('journal-$entryId'),
          child: EntryDetailsPage(itemId: entryId),
        ),
    ];
  }
}
