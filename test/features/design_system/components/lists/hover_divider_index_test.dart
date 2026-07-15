import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';

/// Minimal host that mixes in [HoverDividerIndex] and exposes its API so the
/// mixin's fade logic and hover bookkeeping can be exercised in isolation,
/// independent of any list widget that consumes it.
class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with HoverDividerIndex<_Host> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('HoverDividerIndex', () {
    late GlobalKey<_HostState> key;

    Future<_HostState> pumpHost(WidgetTester tester) async {
      key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      return key.currentState!;
    }

    /// The set of row indices in `0..<count>` whose divider currently fades.
    Set<int> fadedRows(_HostState state, {required int count}) => {
      for (var i = 0; i < count; i++)
        if (state.hoverDividerColorFor(i) == Colors.transparent) i,
    };

    testWidgets('idle: every divider keeps the default (null) colour', (
      tester,
    ) async {
      final state = await pumpHost(tester);
      for (var i = 0; i < 5; i++) {
        expect(state.hoverDividerColorFor(i), isNull);
      }
    });

    testWidgets('hovering a row fades its own divider and the one above', (
      tester,
    ) async {
      final state = await pumpHost(tester);

      state.onRowHoverChanged(2, hovered: true);
      await tester.pump();

      // Row 2's own bottom divider (index 2) plus row 1's bottom divider
      // (the divider directly above row 2) fade — the hovered row is
      // bracketed by invisible hairlines, nothing else changes.
      expect(fadedRows(state, count: 5), {1, 2});
    });

    testWidgets('hovering row 0 fades only its own divider (no row above)', (
      tester,
    ) async {
      final state = await pumpHost(tester);

      state.onRowHoverChanged(0, hovered: true);
      await tester.pump();

      expect(fadedRows(state, count: 5), {0});
    });

    testWidgets('leaving the hovered row clears every fade', (tester) async {
      final state = await pumpHost(tester);

      state.onRowHoverChanged(2, hovered: true);
      await tester.pump();
      expect(fadedRows(state, count: 5), isNotEmpty);

      state.onRowHoverChanged(2, hovered: false);
      await tester.pump();
      expect(fadedRows(state, count: 5), isEmpty);
    });

    testWidgets(
      'a stale leave for a non-current row does not clear the active fade',
      (tester) async {
        final state = await pumpHost(tester);

        // Enter row 3, then a leave arrives for the previously-hovered row 1
        // (out-of-order during a row-to-row move). The leave must be ignored
        // because row 1 is no longer the hovered index.
        state
          ..onRowHoverChanged(3, hovered: true)
          ..onRowHoverChanged(1, hovered: false);
        await tester.pump();

        expect(fadedRows(state, count: 6), {2, 3});
      },
    );

    testWidgets('entering a new row retargets the fade', (tester) async {
      final state = await pumpHost(tester);

      state.onRowHoverChanged(1, hovered: true);
      await tester.pump();
      expect(fadedRows(state, count: 6), {0, 1});

      state.onRowHoverChanged(4, hovered: true);
      await tester.pump();
      expect(fadedRows(state, count: 6), {3, 4});
    });

    testWidgets(
      'a hover callback after dispose is a no-op (no setState after dispose)',
      (tester) async {
        final state = await pumpHost(tester);

        // Tear the host down; a MouseRegion/InkWell can still dispatch a
        // hover-exit callback while the row is being disposed.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(state.mounted, isFalse);

        // The guard must swallow the late callback instead of throwing a
        // "setState() called after dispose()" error.
        expect(
          () => state.onRowHoverChanged(2, hovered: false),
          returnsNormally,
        );
      },
    );
  });
}
