import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/ui/query/query_ask_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);
  testWidgets('feature flag hides Ask and prevents opening until enabled', (
    tester,
  ) async {
    const scope = QueryScope(kind: QueryScopeKind.task, id: 'penguin');
    final flags = StreamController<bool>.broadcast();
    addTearDown(flags.close);
    await tester.pumpWidget(
      makeTestableWidget(
        const QueryAskButton(scope: scope),
        overrides: [
          configFlagProvider(
            'enable_query_chat',
          ).overrideWith((ref) => flags.stream),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(QueryAskButton)),
    );
    expect(find.text('Ask'), findsNothing);
    container.read(queryPaneOpenProvider(scope).notifier).open = true;
    expect(container.read(queryPaneOpenProvider(scope)), isFalse);
    flags.add(true);
    await tester.pump();
    await tester.tap(find.text('Ask'));
    expect(container.read(queryPaneOpenProvider(scope)), isTrue);
    flags.add(false);
    await tester.pump();
    expect(find.text('Ask'), findsNothing);
    expect(container.read(queryPaneOpenProvider(scope)), isFalse);
    flags.add(true);
    await tester.pump();
    expect(find.text('Ask'), findsOneWidget);
    expect(container.read(queryPaneOpenProvider(scope)), isFalse);
  });
  for (final kind in QueryScopeKind.values) {
    testWidgets('opens only the requested ${kind.name} scope', (tester) async {
      final scope = QueryScope(kind: kind, id: 'penguin');
      await tester.pumpWidget(
        makeTestableWidget(
          QueryAskButton(scope: scope),
          overrides: [
            configFlagProvider(
              'enable_query_chat',
            ).overrideWith((ref) => Stream.value(true)),
          ],
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(QueryAskButton)),
      );
      expect(container.read(queryPaneOpenProvider(scope)), isFalse);
      await tester.tap(find.text('Ask'));
      expect(container.read(queryPaneOpenProvider(scope)), isTrue);
      expect(
        container.read(
          queryPaneOpenProvider(QueryScope(kind: kind, id: 'other')),
        ),
        isFalse,
      );
    });
  }
}
