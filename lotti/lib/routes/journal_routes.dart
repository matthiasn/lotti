import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/create/create_text_entry_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal_page.dart';

const AutoRoute journalRoutes = AutoRoute(
  path: 'journal',
  name: 'JournalRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: JournalPage,
    ),
    AutoRoute(
      path: ':entryId',
      page: EntryDetailPage,
    ),
    AutoRoute(
      path: 'create/:linkedId',
      page: CreateTextEntryPage,
    ),
  ],
);
