import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/ui/audio_purge_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockMaintenance extends Mock implements Maintenance {}

void main() {
  late MockMaintenance mockMaintenance;

  setUp(() {
    mockMaintenance = MockMaintenance();
    if (getIt.isRegistered<Maintenance>()) {
      getIt.unregister<Maintenance>();
    }
    getIt.registerSingleton<Maintenance>(mockMaintenance);
  });

  tearDown(() {
    if (getIt.isRegistered<Maintenance>()) {
      getIt.unregister<Maintenance>();
    }
  });

  testWidgets('AudioPurgeModal shows confirmation dialog',
      (WidgetTester tester) async {
    // Setup mock to return Future<void>
    when(() => mockMaintenance.purgeAudioModels())
        .thenAnswer((_) async => Future<void>.value());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AudioPurgeModal.show(context),
              child: const Text('Show Audio Purge Modal'),
            ),
          ),
        ),
      ),
    );

    // Tap the button to show the modal
    await tester.tap(find.text('Show Audio Purge Modal'));
    await tester.pumpAndSettle();

    // Get the confirm button text from the localizations
    final BuildContext context =
        tester.element(find.text('Show Audio Purge Modal'));
    final confirmText =
        AppLocalizations.of(context)!.maintenancePurgeAudioModelsConfirm;

    // Verify the confirmation dialog is shown
    expect(
      find.text(
        AppLocalizations.of(context)!.maintenancePurgeAudioModelsMessage,
      ),
      findsOneWidget,
    );
    expect(find.text(confirmText), findsOneWidget);

    // Tap the confirm button to proceed to progress page
    await tester.tap(find.text(confirmText));
    await tester.pump();

    // Verify that purgeAudioModels was called
    verify(() => mockMaintenance.purgeAudioModels()).called(1);

    // Check for success state immediately after operation completes
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('AudioPurgeModal handles errors gracefully',
      (WidgetTester tester) async {
    // Setup mock to throw error
    when(() => mockMaintenance.purgeAudioModels())
        .thenAnswer((_) async => throw Exception('Test error'));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AudioPurgeModal.show(context),
              child: const Text('Show Audio Purge Modal'),
            ),
          ),
        ),
      ),
    );

    // Tap the button to show the modal
    await tester.tap(find.text('Show Audio Purge Modal'));
    await tester.pumpAndSettle();

    // Get the confirm button text from the localizations
    final BuildContext context =
        tester.element(find.text('Show Audio Purge Modal'));
    final confirmText =
        AppLocalizations.of(context)!.maintenancePurgeAudioModelsConfirm;

    // Tap the confirm button to proceed to progress page
    await tester.tap(find.text(confirmText));
    await tester.pump();

    // Verify that purgeAudioModels was called
    verify(() => mockMaintenance.purgeAudioModels()).called(1);

    // Check for error state immediately after operation fails
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Exception: Test error'), findsOneWidget);
  });
}
