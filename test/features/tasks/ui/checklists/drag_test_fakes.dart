// Shared super_drag_and_drop fakes for the checklists tests. Fakes (not
// mocks): DropSession/DropItem mix in Diagnosticable, which breaks
// mocktail's noSuchMethod-based toString override.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Minimal [DropSession] fake exposing a fixed item list.
class FakeDndDropSession extends Fake implements DropSession {
  FakeDndDropSession({required this.itemList});

  final List<DropItem> itemList;

  @override
  List<DropItem> get items => itemList;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'FakeDndDropSession(items: $itemList)';
}

/// Minimal [DropItem] fake carrying local data only.
class FakeDndDropItem extends Fake implements DropItem {
  FakeDndDropItem({this.testLocalData});

  final Object? testLocalData;

  @override
  Object? get localData => testLocalData;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'FakeDndDropItem(localData: $testLocalData)';
}

/// Minimal [DragSession] fake. The production `dragItemProvider` ignores
/// the session entirely, so an empty stand-in suffices.
class FakeDndDragSession extends Fake implements DragSession {}
