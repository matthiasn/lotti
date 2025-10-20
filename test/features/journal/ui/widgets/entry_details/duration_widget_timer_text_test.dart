import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/duration_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this._entry);

  final JournalEntry _entry;
  bool stopCalled = false;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }

  @override
  Future<void> save(
      {Duration? estimate, String? title, bool stopRecording = false}) async {
    stopCalled = stopRecording;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTimeService mockTimeService;
  late StreamController<JournalEntity?> controller;

  setUpAll(() {
    // Fallbacks for mocktail `any<JournalEntity>()`
    registerFallbackValue(testTextEntry);
  });

  setUp(() {
    mockTimeService = MockTimeService();
    controller = StreamController<JournalEntity?>.broadcast();

    getIt.registerSingleton<TimeService>(mockTimeService);
    // Required by EntryController base class
    if (!getIt.isRegistered<EditorStateService>()) {
      getIt.registerSingleton<EditorStateService>(MockEditorStateService());
    }
    if (!getIt.isRegistered<JournalDb>()) {
      getIt.registerSingleton<JournalDb>(MockJournalDb());
    }
    if (!getIt.isRegistered<UpdateNotifications>()) {
      final mockUpdate = MockUpdateNotifications();
      when(() => mockUpdate.updateStream)
          .thenAnswer((_) => const Stream<Set<String>>.empty());
      getIt.registerSingleton<UpdateNotifications>(mockUpdate);
    }
    when(() => mockTimeService.getStream())
        .thenAnswer((_) => controller.stream);
    when(() => mockTimeService.start(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await controller.close();
    await getIt.reset();
  });

  testWidgets('shows record icon when recent and starts recording on tap',
      (tester) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      meta: Metadata(
        id: 'e-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now.subtract(const Duration(minutes: 1)),
        dateTo: now,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DurationWidget(
          item: entry,
          linkedFrom: null,
        ),
        overrides: [
          entryControllerProvider(id: entry.meta.id)
              .overrideWith(() => _TestEntryController(entry)),
        ],
      ),
    );

    await tester.pumpAndSettle();

    // Text style should have tabular figures
    final textFinder = find.byType(Text);
    final textWidget = tester.widget<Text>(textFinder.first);
    expect(
      textWidget.style?.fontFeatures?.any((ff) => ff.feature == 'tnum') ??
          false,
      isTrue,
    );

    // Record icon visible and clickable
    expect(find.byIcon(Icons.fiber_manual_record_sharp), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fiber_manual_record_sharp));
    await tester.pump();

    verify(() => mockTimeService.start(any(), any())).called(1);
  });

  testWidgets(
      'shows stop icon when recording and calls save(stopRecording: true)',
      (tester) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      meta: Metadata(
        id: 'e-2',
        createdAt: now,
        updatedAt: now,
        dateFrom: now.subtract(const Duration(minutes: 1)),
        dateTo: now,
      ),
    );

    late _TestEntryController ctrl;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DurationWidget(
          item: entry,
          linkedFrom: null,
        ),
        overrides: [
          entryControllerProvider(id: entry.meta.id).overrideWith(() {
            return ctrl = _TestEntryController(entry);
          }),
        ],
      ),
    );

    // Emit a recording snapshot with the same id -> isRecording = true
    controller.add(entry);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.stop), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    expect(ctrl.stopCalled, isTrue);
  });
}
