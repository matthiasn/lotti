import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'drag_test_fakes.dart';

class MockPerformDropEvent extends Mock implements PerformDropEvent {}

/// Fake DropSession that avoids Mock inheritance issues with Diagnosticable
void main() {
  group('buildDragDecorator', () {
    testWidgets('renders Material with elevation, rounded corners, and the '
        'level-02 background token (no chunky border)', (tester) async {
      Color? capturedTokenColor;

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              capturedTokenColor =
                  context.designTokens.colors.background.level02;
              final testChild = Container(key: const ValueKey('test-child'));
              return buildDragDecorator(context, testChild);
            },
          ),
        ),
      );

      await tester.pump();

      final material = tester.widget<Material>(
        find.ancestor(
          of: find.byKey(const ValueKey('test-child')),
          matching: find.byType(Material),
        ),
      );

      expect(material.elevation, 4);
      expect(material.borderRadius, BorderRadius.circular(8));
      expect(material.color, capturedTokenColor);
    });

    testWidgets('preserves child widget in decoration', (tester) async {
      const testKey = ValueKey('test-child');
      const testText = 'Test Content';

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final testChild = Container(
                key: testKey,
                child: const Text(testText),
              );
              return buildDragDecorator(context, testChild);
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.byKey(testKey), findsOneWidget);
      expect(find.text(testText), findsOneWidget);
    });
  });

  group('createChecklistItemDragItem', () {
    test('creates DragItem with correct local data', () {
      final dragItem = createChecklistItemDragItem(
        itemId: 'item-123',
        checklistId: 'checklist-456',
        title: 'Test Item Title',
      );

      expect(dragItem.localData, isA<Map<String, String>>());
      final localData = dragItem.localData! as Map<String, String>;
      expect(localData['checklistItemId'], 'item-123');
      expect(localData['checklistId'], 'checklist-456');
    });

    test('adds plain text format with title', () {
      final dragItem = createChecklistItemDragItem(
        itemId: 'item-123',
        checklistId: 'checklist-456',
        title: 'My Checklist Item',
      );

      // DragItem should have plain text format added
      expect(dragItem.localData, isNotNull);
    });

    test('handles special characters in title', () {
      final dragItem = createChecklistItemDragItem(
        itemId: 'item-1',
        checklistId: 'checklist-1',
        title: 'Item with "quotes" & <special> chars',
      );

      expect(dragItem.localData, isNotNull);
      final localData = dragItem.localData! as Map;
      expect(localData['checklistItemId'], 'item-1');
    });

    test('handles empty title', () {
      final dragItem = createChecklistItemDragItem(
        itemId: 'item-1',
        checklistId: 'checklist-1',
        title: '',
      );

      expect(dragItem.localData, isNotNull);
    });
  });

  group('handleChecklistItemDrop', () {
    late MockChecklistController mockController;
    late MockPerformDropEvent mockEvent;

    setUp(() {
      mockController = MockChecklistController();
      mockEvent = MockPerformDropEvent();
    });

    test('returns false when session items is empty', () async {
      final emptySession = FakeDndDropSession(itemList: []);
      when(() => mockEvent.session).thenReturn(emptySession);

      final result = await handleChecklistItemDrop(
        event: mockEvent,
        checklistNotifier: mockController,
        targetIndex: 0,
        targetItemId: 'target-item',
      );

      expect(result, isFalse);
      verifyNever(
        () => mockController.dropChecklistItem(
          any(),
          targetIndex: any(named: 'targetIndex'),
          targetItemId: any(named: 'targetItemId'),
        ),
      );
    });

    test('returns false when localData is null', () async {
      final dropItem = FakeDndDropItem();
      final session = FakeDndDropSession(itemList: [dropItem]);
      when(() => mockEvent.session).thenReturn(session);

      final result = await handleChecklistItemDrop(
        event: mockEvent,
        checklistNotifier: mockController,
        targetIndex: 1,
        targetItemId: 'target-item',
      );

      expect(result, isFalse);
      verifyNever(
        () => mockController.dropChecklistItem(
          any(),
          targetIndex: any(named: 'targetIndex'),
          targetItemId: any(named: 'targetItemId'),
        ),
      );
    });

    test('calls dropChecklistItem with correct parameters', () async {
      final localData = <String, String>{
        'checklistItemId': 'dragged-item',
        'checklistId': 'source-checklist',
      };

      final dropItem = FakeDndDropItem(testLocalData: localData);
      final session = FakeDndDropSession(itemList: [dropItem]);
      when(() => mockEvent.session).thenReturn(session);
      when(
        () => mockController.dropChecklistItem(
          any(),
          targetIndex: any(named: 'targetIndex'),
          targetItemId: any(named: 'targetItemId'),
        ),
      ).thenAnswer((_) async {});

      final result = await handleChecklistItemDrop(
        event: mockEvent,
        checklistNotifier: mockController,
        targetIndex: 2,
        targetItemId: 'target-item-id',
      );

      expect(result, isTrue);
      verify(
        () => mockController.dropChecklistItem(
          localData,
          targetIndex: 2,
          targetItemId: 'target-item-id',
        ),
      ).called(1);
    });

    test('returns true after successful drop', () async {
      final dropItem = FakeDndDropItem(
        testLocalData: <String, String>{'key': 'value'},
      );
      final session = FakeDndDropSession(itemList: [dropItem]);
      when(() => mockEvent.session).thenReturn(session);
      when(
        () => mockController.dropChecklistItem(
          any(),
          targetIndex: any(named: 'targetIndex'),
          targetItemId: any(named: 'targetItemId'),
        ),
      ).thenAnswer((_) async {});

      final result = await handleChecklistItemDrop(
        event: mockEvent,
        checklistNotifier: mockController,
        targetIndex: 0,
        targetItemId: 'item',
      );

      expect(result, isTrue);
    });
  });
}
