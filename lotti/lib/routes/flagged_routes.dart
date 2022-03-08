import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/flagged_entries_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';

const AutoRoute flaggedRoutes = AutoRoute(
  path: 'flagged',
  name: 'FlaggedRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: FlaggedEntriesPage,
    ),
    AutoRoute(
      path: ':entryId',
      page: EntryDetailPage,
    ),
  ],
);
