import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_helper.dart';

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    // Silence drift's multiple database warning in unit tests
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    await getIt.reset();
    // Minimal registrations needed by MaintenancePage/SliverBoxAdapterPage
    getIt.registerSingleton<UserActivityService>(UserActivityService());
    // ignore: cascade_invocations
    getIt.registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true));
    // ignore: cascade_invocations
    getIt.registerSingleton<Maintenance>(Maintenance());
  });

  tearDown(() async {
    if (getIt.isRegistered<JournalDb>()) {
      await getIt<JournalDb>().close();
    }
    await getIt.reset();
  });

  Future<void> openResetHints(WidgetTester tester) async {
    await tester.pumpWidget(const WidgetTestBench(child: MaintenancePage()));
    await tester.pumpAndSettle();

    // Tap the reset hints card by its title
    final resetTitle = find.text('Reset In‑App Hints');
    expect(resetTitle, findsOneWidget);
    await tester.tap(resetTitle);
    await tester.pumpAndSettle();

    // Confirm in modal (label is uppercased in modal implementation)
    await tester.tap(find.text('CONFIRM'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows SnackBar with count: 0', (tester) async {
    SharedPreferences.setMockInitialValues({
      'other_key': true,
    });

    await openResetHints(tester);

    expect(find.text('Reset zero hints'), findsOneWidget);
  });

  testWidgets('shows SnackBar with count: 1', (tester) async {
    SharedPreferences.setMockInitialValues({
      'seen_tooltip_x': true,
      'random': false,
    });

    await openResetHints(tester);

    expect(find.text('Reset one hint'), findsOneWidget);
  });

  testWidgets('shows SnackBar with count: many', (tester) async {
    SharedPreferences.setMockInitialValues({
      'seen_a': true,
      'seen_b': true,
      'foo': true,
    });

    await openResetHints(tester);
    expect(find.text('Reset 2 hints'), findsOneWidget);
  });
}
