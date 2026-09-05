import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

enum _TestFilter {
  waiting,
  failed,
}

class _TestItem {
  const _TestItem();
}

void main() {
  group('SyncHeaderBottom', () {
    testWidgets(
      'preferred height grows when token-sized chips wrap',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SizedBox.shrink(),
            theme: DesignSystemTheme.light(),
          ),
        );

        final context = tester.element(find.byType(Scaffold));
        final wideHeight = SyncHeaderBottom.calculatePreferredHeight(
          context: context,
          labels: const ['Waiting', 'Failed'],
          counts: const [12, 3],
          haveIcons: const [true, true],
          showCounts: const [true, true],
          availableWidth: 600,
          horizontalPadding: 0,
          summaryText: '2 queued entries',
        );
        final narrowHeight = SyncHeaderBottom.calculatePreferredHeight(
          context: context,
          labels: const ['Waiting', 'Failed'],
          counts: const [12, 3],
          haveIcons: const [true, true],
          showCounts: const [true, true],
          availableWidth: 1,
          horizontalPadding: 0,
          summaryText: '2 queued entries',
        );

        expect(narrowHeight, greaterThan(wideHeight));
      },
    );

    testWidgets(
      'uses selectable design-system chips and a semantic count pill',
      (tester) async {
        final semantics = tester.ensureSemantics();
        const accent = Color(0xFF9B2D30);
        _TestFilter? changedTo;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SyncHeaderBottom<_TestItem, _TestFilter>(
              filters: {
                _TestFilter.waiting: SyncFilterOption<_TestItem>(
                  labelBuilder: (_) => 'waiting',
                  predicate: (_) => true,
                  icon: LottiIcons.schedule,
                  hideCountWhenZero: true,
                ),
                _TestFilter.failed: SyncFilterOption<_TestItem>(
                  labelBuilder: (_) => 'failed',
                  predicate: (_) => true,
                  icon: LottiIcons.error,
                  countAccentColor: accent,
                ),
              },
              counts: const {
                _TestFilter.waiting: 0,
                _TestFilter.failed: 2,
              },
              selected: _TestFilter.waiting,
              onChanged: (value) => changedTo = value,
              locale: 'en',
              summaryText: '',
              padding: EdgeInsetsDirectional.zero,
              preferredHeight: 80,
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        expect(find.byType(DesignSystemChip), findsNWidgets(2));
        expect(find.byType(DsPill), findsOneWidget);
        expect(find.text('0'), findsNothing);

        final waitingChip = tester.widget<DesignSystemChip>(
          find.byKey(const ValueKey('syncFilter-waiting')),
        );
        final failedChip = tester.widget<DesignSystemChip>(
          find.byKey(const ValueKey('syncFilter-failed')),
        );
        final countPill = tester.widget<DsPill>(find.byType(DsPill));

        expect(waitingChip.selected, isTrue);
        expect(failedChip.selected, isFalse);
        expect(failedChip.semanticsLabel, 'Failed, 2');
        expect(countPill.variant, DsPillVariant.outline);
        expect(countPill.label, '2');
        expect(countPill.color, accent);
        expect(find.bySemanticsLabel('Failed, 2'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('syncFilter-failed')));
        await tester.pump();

        expect(changedTo, _TestFilter.failed);
        semantics.dispose();
      },
    );
  });
}
