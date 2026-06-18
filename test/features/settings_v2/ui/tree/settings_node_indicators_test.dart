import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/ui/tree/outbox_count_indicator.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_node_indicators.dart';

void main() {
  group('settingsNodeIndicatorFor', () {
    test('maps sync/outbox to the live count indicator', () {
      expect(
        settingsNodeIndicatorFor('sync/outbox'),
        isA<OutboxCountIndicator>(),
      );
    });

    test('returns null for nodes without a registered indicator', () {
      expect(settingsNodeIndicatorFor('sync/stats'), isNull);
      expect(settingsNodeIndicatorFor('theming'), isNull);
      expect(settingsNodeIndicatorFor('definitions/categories'), isNull);
    });
  });
}
