import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/copy/demo_copy_candidates.dart';
import 'package:lotti/features/demo/ui/demo_exit_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockDemoModeGateway gateway;

  final task = TestTaskFactory.create(id: 'task-1', title: 'Pack fish crates');
  final note = JournalEntry(
    meta: TestMetadataFactory.create(id: 'note-1'),
    entryText: const EntryText(plainText: 'First line\nSecond line'),
  );

  setUp(() {
    gateway = MockDemoModeGateway();
  });

  Widget host(Future<DemoCopyCandidates> Function() loadCandidates) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showDemoExitSheet(
                  context,
                  gateway: gateway,
                  loadCandidates: loadCandidates,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('with no candidates the take-work path is absent and Exit '
      'demo exits directly', (tester) async {
    final exited = Completer<void>();
    when(gateway.exitDemo).thenAnswer((_) => exited.future);
    await tester.pumpWidget(
      host(() async => DemoCopyCandidates.empty),
    );
    await open(tester);

    expect(find.text('Leave the demo?'), findsOneWidget);
    expect(find.text('Take my work with me…'), findsNothing);

    await tester.tap(find.text('Exit demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(gateway.exitDemo).called(1);
    // The working step surfaces a spinner until the generation switch
    // unmounts the sheet — but never the copy message on a plain exit.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Copying your work…'), findsNothing);
    exited.complete();
    await tester.pump();
  });

  testWidgets('selection flow: nothing preselected, select all toggles, '
      'confirm copies exactly the selection', (tester) async {
    when(
      () => gateway.exitWithCopy(selectedIds: any(named: 'selectedIds')),
    ).thenAnswer((_) async => 2);
    await tester.pumpWidget(
      host(
        () async => DemoCopyCandidates(tasks: [task], entries: [note]),
      ),
    );
    await open(tester);

    // Step 1 offers the take-work path when candidates exist.
    await tester.tap(find.text('Take my work with me…'));
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Journal entries'), findsOneWidget);
    expect(find.text('Pack fish crates'), findsOneWidget);
    expect(
      find.text('First line'),
      findsOneWidget,
      reason: 'entry rows are labelled by their first text line',
    );

    // Nothing preselected: confirm is disabled.
    DesignSystemButton confirmButton() => tester.widget<DesignSystemButton>(
      find.widgetWithText(DesignSystemButton, 'Copy and exit'),
    );
    expect(confirmButton().onPressed, isNull);

    // Select all, then deselect one: only the remaining id is copied.
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(confirmButton().onPressed, isNotNull);
    await tester.tap(find.text('First line'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy and exit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final captured = verify(
      () => gateway.exitWithCopy(selectedIds: captureAny(named: 'selectedIds')),
    ).captured;
    expect(captured.single, {'task-1'});
    expect(find.text('Copying your work…'), findsOneWidget);
  });

  testWidgets('select all selects every candidate across both sections', (
    tester,
  ) async {
    when(
      () => gateway.exitWithCopy(selectedIds: any(named: 'selectedIds')),
    ).thenAnswer((_) async => 2);
    await tester.pumpWidget(
      host(
        () async => DemoCopyCandidates(tasks: [task], entries: [note]),
      ),
    );
    await open(tester);
    await tester.tap(find.text('Take my work with me…'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy and exit'));
    await tester.pump();

    final captured = verify(
      () => gateway.exitWithCopy(selectedIds: captureAny(named: 'selectedIds')),
    ).captured;
    expect(captured.single, {'task-1', 'note-1'});
  });

  testWidgets('cancel closes the sheet without touching the gateway', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(() async => DemoCopyCandidates.empty),
    );
    await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Leave the demo?'), findsNothing);
    verifyNever(gateway.exitDemo);
    verifyNever(
      () => gateway.exitWithCopy(selectedIds: any(named: 'selectedIds')),
    );
  });
}
