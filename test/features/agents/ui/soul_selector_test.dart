import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/soul_selector.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  Widget buildSubject({
    String? selectedSoulId,
    ValueChanged<String?>? onSoulSelected,
    List<AgentDomainEntity> souls = const [],
  }) {
    return makeTestableWidgetNoScroll(
      Scaffold(
        body: SoulSelector(
          selectedSoulId: selectedSoulId,
          onSoulSelected: onSoulSelected ?? (_) {},
        ),
      ),
      theme: DesignSystemTheme.light(),
      overrides: [
        allSoulDocumentsProvider.overrideWith(
          (ref) async => souls,
        ),
      ],
    );
  }

  group('SoulSelector', () {
    testWidgets('shows placeholder when no soul selected', (tester) async {
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
      ];

      await tester.pumpWidget(buildSubject(souls: souls));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulSelector));
      expect(
        find.text(context.messages.agentSoulNoneAssigned),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulAssignmentLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows selected soul name', (tester) async {
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
        makeTestSoulDocument(id: 's2', displayName: 'Tom'),
      ];

      await tester.pumpWidget(
        buildSubject(selectedSoulId: 's1', souls: souls),
      );
      await tester.pumpAndSettle();

      expect(find.text('Laura'), findsOneWidget);
    });

    testWidgets('shows clear button when soul is selected', (tester) async {
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
      ];

      await tester.pumpWidget(
        buildSubject(selectedSoulId: 's1', souls: souls),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('no clear button when no soul selected', (tester) async {
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
      ];

      await tester.pumpWidget(buildSubject(souls: souls));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('clear button calls onSoulSelected with null', (
      tester,
    ) async {
      String? selectedId = 's1';
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
      ];

      await tester.pumpWidget(
        buildSubject(
          selectedSoulId: selectedId,
          onSoulSelected: (id) => selectedId = id,
          souls: souls,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(selectedId, isNull);
    });

    testWidgets('opens picker modal on tap', (tester) async {
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
        makeTestSoulDocument(id: 's2', displayName: 'Tom'),
      ];

      await tester.pumpWidget(buildSubject(souls: souls));
      await tester.pumpAndSettle();

      // Tap the selector (on the placeholder text area).
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulSelector));
      expect(
        find.text(context.messages.agentSoulSelectTitle),
        findsOneWidget,
      );
      expect(find.text('Laura'), findsWidgets);
      expect(find.text('Tom'), findsOneWidget);
    });

    testWidgets('selecting soul in picker calls onSoulSelected', (
      tester,
    ) async {
      String? selectedId;
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
        makeTestSoulDocument(id: 's2', displayName: 'Tom'),
      ];

      await tester.pumpWidget(
        buildSubject(
          onSoulSelected: (id) => selectedId = id,
          souls: souls,
        ),
      );
      await tester.pumpAndSettle();

      // Open picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Select Tom.
      await tester.tap(find.text('Tom').last);
      await tester.pumpAndSettle();

      expect(selectedId, 's2');
    });

    testWidgets('selected soul shows checkmark in picker', (tester) async {
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
        makeTestSoulDocument(id: 's2', displayName: 'Tom'),
      ];

      await tester.pumpWidget(
        buildSubject(selectedSoulId: 's1', souls: souls),
      );
      await tester.pumpAndSettle();

      // Open picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('disabled when no souls available', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // The InputDecorator should show disabled state — tapping should
      // not open a picker.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // No modal should appear.
      final context = tester.element(find.byType(SoulSelector));
      expect(
        find.text(context.messages.agentSoulSelectTitle),
        findsNothing,
      );
    });

    testWidgets('shows psychology icon in picker items', (tester) async {
      final souls = [
        makeTestSoulDocument(id: 's1', displayName: 'Laura'),
      ];

      await tester.pumpWidget(buildSubject(souls: souls));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    });
  });
}
