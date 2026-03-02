import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_realtime_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String? partialTranscript,
    VoidCallback? onCancel,
    VoidCallback? onStop,
  }) {
    return makeTestableWidgetWithScaffold(
      EvolutionRealtimeView(
        partialTranscript: partialTranscript,
        onCancel: onCancel ?? () {},
        onStop: onStop ?? () {},
      ),
    );
  }

  testWidgets('shows listening indicator when no transcript', (tester) async {
    await tester.pumpWidget(buildSubject());
    // Use pump() — CircularProgressIndicator never settles
    await tester.pump();

    final context = tester.element(find.byType(EvolutionRealtimeView));
    expect(
      find.text(context.messages.chatInputListening),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows partial transcript text', (tester) async {
    await tester.pumpWidget(
      buildSubject(partialTranscript: 'Hello world'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('cancel button invokes onCancel', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      buildSubject(onCancel: () => cancelled = true),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cancelled, isTrue);
  });

  testWidgets('stop button invokes onStop', (tester) async {
    var stopped = false;
    await tester.pumpWidget(
      buildSubject(onStop: () => stopped = true),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();

    expect(stopped, isTrue);
  });

  testWidgets('has correct tooltips', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final context = tester.element(find.byType(EvolutionRealtimeView));
    expect(
      find.byTooltip(context.messages.chatInputCancelRealtime),
      findsOneWidget,
    );
    expect(
      find.byTooltip(context.messages.chatInputStopRealtime),
      findsOneWidget,
    );
  });
}
