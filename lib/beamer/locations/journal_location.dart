import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal/journal_page.dart';

class JournalLocation extends BeamLocation<BeamState> {
  JournalLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/journal/:entryId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('journal'),
          title: 'Journal',
          type: BeamPageType.noTransition,
          child: JournalPage(),
        ),
        if (state.pathParameters.containsKey('entryId'))
          BeamPage(
            key: ValueKey('journal-${state.pathParameters['entryId']}'),
            child: EntryDetailPage(
              itemId: state.pathParameters['entryId']!,
            ),
          ),
      ];
}
