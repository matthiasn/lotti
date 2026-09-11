import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/ui/query/query_ask_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  for (final kind in QueryScopeKind.values) {
    testWidgets('opens only the requested ${kind.name} scope', (tester) async {
      final scope = QueryScope(kind: kind, id: 'penguin');
      await tester.pumpWidget(makeTestableWidget(QueryAskButton(scope: scope)));
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
