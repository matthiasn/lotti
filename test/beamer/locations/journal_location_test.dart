import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/journal_location.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('JournalLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location =
          JournalLocation(RouteInformation(uri: Uri.parse('/journal')));
      expect(location.pathPatterns, [
        '/journal',
        '/journal/:entryId',
        '/journal/fill_survey/:surveyType'
      ]);
    });

    test('buildPages builds InfiniteJournalPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/journal'));
      final location = JournalLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<InfiniteJournalPage>());
    });

    test('buildPages builds EntryDetailsPage', () {
      final entryId = const Uuid().v4();
      final routeInformation =
          RouteInformation(uri: Uri.parse('/journal/$entryId'));
      final location = JournalLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(
        routeInformation,
      );
      final newPathParameters =
          Map<String, String>.from(beamState.pathParameters);
      newPathParameters['entryId'] = entryId;
      final newBeamState = beamState.copyWith(
        pathParameters: newPathParameters,
      );
      final pages = location.buildPages(
        mockBuildContext,
        newBeamState,
      );
      expect(pages.length, 2);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<InfiniteJournalPage>());
      expect(pages[1].key, isA<ValueKey<String>>());
      expect(pages[1].child, isA<EntryDetailsPage>());
      final entryDetailsPage = pages[1].child as EntryDetailsPage;
      expect(entryDetailsPage.itemId, entryId);
    });

    test('buildPages builds FillSurveyWithTypePage', () {
      const surveyType = 'some-survey';
      final routeInformation =
          RouteInformation(uri: Uri.parse('/journal/fill_survey/$surveyType'));
      final location = JournalLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(
        routeInformation,
      );
      final newPathParameters =
          Map<String, String>.from(beamState.pathParameters);
      newPathParameters['surveyType'] = surveyType;
      final newBeamState = beamState.copyWith(
        pathParameters: newPathParameters,
      );
      final pages = location.buildPages(
        mockBuildContext,
        newBeamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<InfiniteJournalPage>());
    });
  });
}
