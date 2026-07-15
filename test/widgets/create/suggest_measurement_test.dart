import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/create/suggest_measurement.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../pages/create/test_utils.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  late MockJournalDb mockJournalDb;

  setUp(() async {
    mockJournalDb = MockJournalDb();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpSuggestions(
    WidgetTester tester, {
    required List<MeasurementEntry> measurements,
    required Future<void> Function(num) onSelect,
    bool enabled = true,
  }) async {
    when(
      () => mockJournalDb.getMeasurementsByType(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
        type: measurableWater.id,
      ),
    ).thenAnswer((_) async => measurements);

    await tester.pumpWidget(
      makeTestableWidget(
        MeasurementSuggestions(
          measurableDataType: measurableWater,
          enabled: enabled,
          onSelect: onSelect,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders nothing when no recent values are available', (
    tester,
  ) async {
    await pumpSuggestions(
      tester,
      measurements: const [],
      onSelect: (_) async {},
    );

    expect(find.text('Quick log'), findsNothing);
    expect(find.byType(DesignSystemChip), findsNothing);
  });

  testWidgets('quick-log chips expose intent, save once, and disable safely', (
    tester,
  ) async {
    num? selectedValue;
    final measurements = measurementSuggestionFixture();

    await pumpSuggestions(
      tester,
      measurements: measurements,
      onSelect: (value) async => selectedValue = value,
    );

    expect(find.text('Quick log'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget);
    expect(find.text('250 ml'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('500 ml')).label,
      contains('Log 500 ml immediately'),
    );

    await tester.tap(find.text('500 ml'));
    await tester.pump();
    expect(selectedValue, 500);

    await pumpSuggestions(
      tester,
      measurements: measurements,
      enabled: false,
      onSelect: (_) async => selectedValue = -1,
    );
    final chips = tester.widgetList<DesignSystemChip>(
      find.byType(DesignSystemChip),
    );
    expect(chips, isNotEmpty);
    expect(chips.every((chip) => chip.onPressed == null), isTrue);
    expect(selectedValue, 500);
  });
}
