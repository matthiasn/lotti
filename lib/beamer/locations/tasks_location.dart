import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/create/record_audio_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal/infinite_journal_page.dart';
import 'package:lotti/utils/uuid.dart';

class TasksLocation extends BeamLocation<BeamState> {
  TasksLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/tasks/:entryId',
        '/tasks/:entryId/record_audio/:linkedId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);

    final entryId = state.pathParameters['entryId'];
    final linkedId = state.pathParameters['linkedId'];

    return [
      const BeamPage(
        key: ValueKey('tasks'),
        title: 'Tasks',
        type: BeamPageType.noTransition,
        child: InfiniteJournalPage(showTasks: true),
      ),
      if (isUuid(entryId))
        BeamPage(
          key: ValueKey('tasks-$entryId'),
          child: EntryDetailPage(itemId: entryId!),
        ),
      if (pathContains('record_audio/'))
        BeamPage(
          key: ValueKey('record_audio-$linkedId'),
          child: RecordAudioPage(linkedId: linkedId),
        ),
    ];
  }
}
