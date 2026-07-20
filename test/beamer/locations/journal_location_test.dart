import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/journal_location.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/pages/journal_root_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../mocks/mocks.dart';

void main() {
  group('JournalLocation', () {
    late MockBuildContext mockBuildContext;
    late MockNavService mockNavService;
    late ValueNotifier<String?> desktopSelectedEntryId;

    setUp(() async {
      mockBuildContext = MockBuildContext();
      mockNavService = MockNavService();
      desktopSelectedEntryId = ValueNotifier<String?>(null);
      when(() => mockNavService.isDesktopMode).thenReturn(false);
      when(
        () => mockNavService.desktopSelectedEntryId,
      ).thenReturn(desktopSelectedEntryId);
      await getIt.reset();
      getIt.registerSingleton<NavService>(mockNavService);
    });

    tearDown(() async {
      desktopSelectedEntryId.dispose();
      await getIt.reset();
    });

    List<BeamPage> buildPagesFor(Uri uri, Map<String, String> pathParameters) {
      final routeInformation = RouteInformation(uri: uri);
      final location = JournalLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final state = beamState.copyWith(
        pathParameters: {...beamState.pathParameters, ...pathParameters},
      );
      return location.buildPages(mockBuildContext, state);
    }

    test('pathPatterns are correct', () {
      final location = JournalLocation(
        RouteInformation(uri: Uri.parse('/journal')),
      );
      expect(location.pathPatterns, [
        '/journal',
        '/journal/:entryId',
        '/journal/fill_survey/:surveyType',
      ]);
    });

    test('root route builds JournalRootPage only', () {
      final pages = buildPagesFor(Uri.parse('/journal'), {});
      expect(pages.length, 1);
      expect(pages[0].child, isA<JournalRootPage>());
    });

    group('mobile (isDesktopMode false)', () {
      test('entry uuid pushes EntryDetailsPage on top of the root page', () {
        final entryId = const Uuid().v4();
        final pages = buildPagesFor(
          Uri.parse('/journal/$entryId'),
          {'entryId': entryId},
        );
        expect(pages.length, 2);
        expect(pages[0].child, isA<JournalRootPage>());
        final detailsPage = pages[1].child as EntryDetailsPage;
        expect(detailsPage.itemId, entryId);
        // Pushed as its own route, so back must be available.
        expect(detailsPage.showBackButton, isTrue);
      });

      test('does not write the desktop selection notifier', () async {
        final entryId = const Uuid().v4();
        buildPagesFor(Uri.parse('/journal/$entryId'), {'entryId': entryId});
        // Writes are scheduled in a microtask; drain the queue so this
        // asserts "never written", not just "not written yet".
        await Future<void>.microtask(() {});
        expect(desktopSelectedEntryId.value, isNull);
      });

      test('non-uuid entryId resolves to the root page only', () {
        final pages = buildPagesFor(
          Uri.parse('/journal/not-a-uuid'),
          {'entryId': 'not-a-uuid'},
        );
        expect(pages.length, 1);
        expect(pages[0].child, isA<JournalRootPage>());
      });
    });

    group('desktop (isDesktopMode true)', () {
      setUp(() {
        when(() => mockNavService.isDesktopMode).thenReturn(true);
      });

      test('entry uuid stays a single page and selects the entry', () async {
        final entryId = const Uuid().v4();
        final pages = buildPagesFor(
          Uri.parse('/journal/$entryId'),
          {'entryId': entryId},
        );
        // The split pane shows the details; no second route is pushed.
        expect(pages.length, 1);
        expect(pages[0].child, isA<JournalRootPage>());
        await Future<void>.microtask(() {});
        expect(desktopSelectedEntryId.value, entryId);
      });

      test('root route clears the selection', () async {
        desktopSelectedEntryId.value = const Uuid().v4();
        buildPagesFor(Uri.parse('/journal'), {});
        await Future<void>.microtask(() {});
        expect(desktopSelectedEntryId.value, isNull);
      });

      test('non-uuid entryId clears the selection', () async {
        desktopSelectedEntryId.value = const Uuid().v4();
        buildPagesFor(
          Uri.parse('/journal/not-a-uuid'),
          {'entryId': 'not-a-uuid'},
        );
        await Future<void>.microtask(() {});
        expect(desktopSelectedEntryId.value, isNull);
      });

      test(
        'skips the write when the NavService was replaced meanwhile',
        () async {
          final entryId = const Uuid().v4();
          buildPagesFor(Uri.parse('/journal/$entryId'), {'entryId': entryId});

          // Simulate a service swap (as tests and restarts do) before the
          // microtask runs: the stale location must not write through to the
          // replacement service's notifier. The swap must happen with no
          // intervening await — the first suspension would let the pending
          // microtask run against the still-registered original.
          final replacement = MockNavService();
          final replacementNotifier = ValueNotifier<String?>(null);
          addTearDown(replacementNotifier.dispose);
          when(() => replacement.isDesktopMode).thenReturn(true);
          when(
            () => replacement.desktopSelectedEntryId,
          ).thenReturn(replacementNotifier);
          getIt
            ..unregister<NavService>()
            ..registerSingleton<NavService>(replacement);

          await Future<void>.microtask(() {});
          expect(replacementNotifier.value, isNull);
          expect(desktopSelectedEntryId.value, isNull);
        },
      );
    });

    test('fill_survey route resolves to the journal root page only', () {
      // `/journal/fill_survey/:surveyType` is a registered path pattern, but
      // buildPages deliberately does NOT push a survey page: the survey is
      // presented modally by the caller, and deep links into it land on the
      // journal root. The surveyType parameter must not be mistaken for an
      // entryId (only UUIDs count as entries).
      final pages = buildPagesFor(
        Uri.parse('/journal/fill_survey/some-survey'),
        {'surveyType': 'some-survey'},
      );
      expect(pages.length, 1);
      expect(pages[0].child, isA<JournalRootPage>());
    });
  });
}
