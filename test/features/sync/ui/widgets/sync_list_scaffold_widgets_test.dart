import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold_widgets.dart';

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
                  icon: Icons.schedule_rounded,
                  hideCountWhenZero: true,
                ),
                _TestFilter.failed: SyncFilterOption<_TestItem>(
                  labelBuilder: (_) => 'failed',
                  predicate: (_) => true,
                  icon: Icons.error_outline_rounded,
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
