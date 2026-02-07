import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ratings/state/rating_prompt_controller.dart';
import 'package:lotti/features/ratings/ui/rating_prompt_listener.dart';

import '../../../widget_test_utils.dart';

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
        ProviderScope(
          child: Builder(
            builder: (context) {
              return MaterialApp(
                home: Consumer(
                  builder: (context, ref, _) {
                    // Capture the container from the ProviderScope
                    container = ProviderScope.containerOf(context);
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
        ),
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
        ProviderScope(
          child: Builder(
            builder: (context) {
              return MaterialApp(
                home: Consumer(
                  builder: (context, ref, _) {
                    container = ProviderScope.containerOf(context);
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
        ),
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
  });
}
