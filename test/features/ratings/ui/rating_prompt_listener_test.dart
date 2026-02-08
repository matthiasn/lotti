import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/ratings/state/rating_prompt_controller.dart';
import 'package:lotti/features/ratings/ui/rating_prompt_listener.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../widget_test_utils.dart';

Widget _buildListenerApp({
  required void Function(ProviderContainer) onContainer,
}) {
  return ProviderScope(
    child: Builder(
      builder: (context) {
        return MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              onContainer(ProviderScope.containerOf(context));
              return const Scaffold(
                body: RatingPromptListener(
                  child: Text('Main Content'),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('RatingPromptListener', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RatingPromptListener(
            child: Text('Child Widget'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Child Widget'), findsOneWidget);
    });

    testWidgets('shows modal when rating prompt becomes non-null',
        (tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        _buildListenerApp(onContainer: (c) => container = c),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main Content'), findsOneWidget);
      expect(find.text('Rate this session'), findsNothing);

      // Trigger rating prompt
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-1');
      await tester.pumpAndSettle();

      // Modal should appear
      expect(find.text('Rate this session'), findsOneWidget);
    });

    testWidgets('does not show modal when state goes from non-null to null',
        (tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        _buildListenerApp(onContainer: (c) => container = c),
      );
      await tester.pumpAndSettle();

      // Set to a value first then dismiss
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-1');
      await tester.pumpAndSettle();

      // Close the modal via Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Dismiss sets state to null; no new modal should appear
      expect(find.text('Rate this session'), findsNothing);
    });

    testWidgets('clears prompt state when modal is dismissed via swipe',
        (tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        _buildListenerApp(onContainer: (c) => container = c),
      );
      await tester.pumpAndSettle();

      // Trigger rating prompt
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-1');
      await tester.pumpAndSettle();

      expect(find.text('Rate this session'), findsOneWidget);

      // Dismiss via drag down (swipe dismiss)
      await tester.drag(find.text('Rate this session'), const Offset(0, 400));
      await tester.pumpAndSettle();

      // State should be cleared
      expect(container.read(ratingPromptControllerProvider), isNull);
    });

    testWidgets('shows new modal after previous was dismissed', (tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        _buildListenerApp(onContainer: (c) => container = c),
      );
      await tester.pumpAndSettle();

      // First rating prompt
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-1');
      await tester.pumpAndSettle();
      expect(find.text('Rate this session'), findsOneWidget);

      // Dismiss via Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Rate this session'), findsNothing);

      // Second rating prompt (different entry)
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-2');
      await tester.pumpAndSettle();

      // New modal should appear
      expect(find.text('Rate this session'), findsOneWidget);
    });
  });
}
