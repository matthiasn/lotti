import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

import '../../../../widget_test_utils.dart';

void main() {
  setUp(() {
    getIt
      ..pushNewScope()
      ..registerSingleton<UserActivityService>(UserActivityService());
  });

  tearDown(() async {
    await getIt.popScope();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Widget child,
    bool showBackButton = false,
    bool fillRemaining = false,
    String? subtitle,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SliverBoxAdapterPage(
          title: 'Page Title',
          subtitle: subtitle,
          showBackButton: showBackButton,
          fillRemaining: fillRemaining,
          child: child,
        ),
      ),
    );
    // Let the 500ms fade-in entrance animation finish.
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('SliverBoxAdapterPage', () {
    testWidgets('renders title, subtitle and the child in box-adapter mode', (
      tester,
    ) async {
      await pumpPage(
        tester,
        subtitle: 'Sub',
        child: const Text('body content'),
      );

      expect(find.text('Page Title'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
      expect(find.text('body content'), findsOneWidget);
      // Default mode hosts the child in SliverToBoxAdapter, not
      // SliverFillRemaining.
      expect(find.byType(SliverFillRemaining), findsNothing);
      expect(find.byType(SliverToBoxAdapter), findsWidgets);
      // No back button by default.
      expect(find.byType(BackWidget), findsNothing);
    });

    testWidgets('shows the back button when requested', (tester) async {
      await pumpPage(
        tester,
        showBackButton: true,
        child: const SizedBox.shrink(),
      );

      expect(find.byType(BackWidget), findsOneWidget);
    });

    testWidgets(
      'fillRemaining hosts the child in a bounded SliverFillRemaining',
      (tester) async {
        await pumpPage(
          tester,
          fillRemaining: true,
          // Expanded requires bounded constraints — this would throw in the
          // default SliverToBoxAdapter mode.
          child: const Column(
            children: [
              Expanded(child: Center(child: Text('expanded body'))),
            ],
          ),
        );

        expect(find.byType(SliverFillRemaining), findsOneWidget);
        expect(find.text('expanded body'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'fillRemaining bridges inner scroll events to user-activity tracking',
      (tester) async {
        final activityService = UserActivityService();
        await getIt.popScope();
        getIt
          ..pushNewScope()
          ..registerSingleton<UserActivityService>(activityService);

        await pumpPage(
          tester,
          fillRemaining: true,
          child: ListView(
            children: List.generate(
              50,
              (i) => SizedBox(height: 50, child: Text('row $i')),
            ),
          ),
        );

        final before = activityService.lastActivity;
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pump();

        expect(activityService.lastActivity.isAfter(before), isTrue);
      },
    );
  });
}
