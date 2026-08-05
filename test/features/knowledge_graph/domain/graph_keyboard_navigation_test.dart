import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_keyboard_navigation.dart';

void main() {
  const positions = <String, Offset>{
    'focus': Offset.zero,
    'right-near': Offset(40, 4),
    'right-off-axis': Offset(15, 40),
    'left': Offset(-20, 0),
    'down': Offset(0, 30),
  };

  test('prefers the visually aligned candidate in an arrow direction', () {
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'focus',
        direction: const Offset(1, 0),
      ),
      'right-near',
    );
  });

  test('excludes nodes behind the requested direction', () {
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'focus',
        direction: const Offset(-1, 0),
      ),
      'left',
    );
  });

  test('returns null for missing origins and zero directions', () {
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'missing',
        direction: const Offset(1, 0),
      ),
      isNull,
    );
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'focus',
        direction: Offset.zero,
      ),
      isNull,
    );
  });
}
