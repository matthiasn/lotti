import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_tab_bar.dart';

import '../../../../../../widget_test_utils.dart';

class _Host extends StatefulWidget {
  const _Host({required this.onTabChanged});

  final ValueChanged<AiSettingsTab> onTabChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: AiSettingsTab.values.length,
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AiSettingsTabBar(
      tabController: _controller,
      providerCount: 2,
      modelCount: 5,
      profileCount: 2,
      onTabChanged: widget.onTabChanged,
    );
  }
}

void main() {
  group('AiSettingsTabBar', () {
    testWidgets(
      'renders one tab per AiSettingsTab value with the label + the count '
      'baked into the same Tab (no separate counters strip)',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(_Host(onTabChanged: (_) {})),
        );
        await tester.pump();
        // Three tab labels, each followed by their count.
        expect(find.text('Providers'), findsOneWidget);
        expect(find.text('Models'), findsOneWidget);
        expect(find.text('Profiles'), findsOneWidget);
        expect(find.text('2'), findsAtLeastNWidgets(1));
        expect(find.text('5'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a tab fires onTabChanged with the matching AiSettingsTab',
      (tester) async {
        final tapped = <AiSettingsTab>[];
        await tester.pumpWidget(
          makeTestableWidget(_Host(onTabChanged: tapped.add)),
        );
        await tester.pump();
        await tester.tap(find.text('Models'));
        await tester.pumpAndSettle();
        expect(tapped.last, equals(AiSettingsTab.models));

        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();
        expect(tapped.last, equals(AiSettingsTab.profiles));
      },
    );
  });
}
