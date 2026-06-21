import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/ui/onboarding_metrics_page.dart';
import 'package:lotti/get_it.dart';

import '../../../widget_test_utils.dart';

void main() {
  late OnboardingMetricsDb db;
  late OnboardingMetricsRepository repo;
  var idSeq = 0;

  setUp(() async {
    await getIt.reset();
    idSeq = 0;
    db = OnboardingMetricsDb(inMemoryDatabase: true);
    repo = OnboardingMetricsRepository(
      db: db,
      clock: () => DateTime.utc(2026, 7, 1, 9),
      idGenerator: () => 'id-${idSeq++}',
      currentPlatform: () => 'testos',
    );
    getIt
      ..registerSingleton<OnboardingMetricsDb>(db)
      ..registerSingleton<OnboardingMetricsRepository>(repo);
  });

  tearDown(() async {
    await getIt.reset();
    await db.close();
  });

  // Pumps without pumpAndSettle: the loading-state CircularProgressIndicator
  // never settles, so we pump a bounded number of frames until the async
  // funnel load resolves.
  Future<void> pumpUntilLoaded(WidgetTester tester, Finder finder) async {
    await tester.pumpWidget(makeTestableWidget(const OnboardingMetricsBody()));
    for (var i = 0; i < 10 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('renders the derived funnel from recorded events', (
    tester,
  ) async {
    await repo.recordAppFirstSeenIfAbsent();
    await repo.recordEvent(OnboardingEventName.firstAudioCaptured);
    await repo.recordEvent(OnboardingEventName.realAha);

    await pumpUntilLoaded(tester, find.text('Reached real aha'));

    // Summary rows render.
    expect(find.text('Reached real aha'), findsOneWidget);
    expect(find.text('Install first seen (UTC)'), findsOneWidget);
    expect(find.text('Active days'), findsOneWidget);
    // Reached-aha is derived as yes from the seeded realAha event.
    expect(find.text('yes'), findsOneWidget);
    // Per-event count rows render for the seeded events.
    expect(
      find.text(OnboardingEventName.firstAudioCaptured.wireName),
      findsOneWidget,
    );
    expect(find.text(OnboardingEventName.realAha.wireName), findsOneWidget);
  });

  testWidgets('renders the empty funnel before any events', (tester) async {
    await pumpUntilLoaded(tester, find.text('Reached real aha'));

    expect(find.text('Reached real aha'), findsOneWidget);
    // No events → reached-aha and baseline both render as no.
    expect(find.text('no'), findsWidgets);
    // Install date is unknown.
    expect(find.text('—'), findsOneWidget);
  });
}
