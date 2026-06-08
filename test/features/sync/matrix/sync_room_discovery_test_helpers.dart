
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// MockMatrixClient and MockStrippedStateEvent come from the centralized
// test/mocks/mocks.dart. RoomSummary has no centralized mock, so it is local.
class MockRoomSummary extends Mock implements RoomSummary {}

class GeneratedRoomDiscoveryCase {
  const GeneratedRoomDiscoveryCase({
    required this.encrypted,
    required this.publicRoom,
    required this.hasStateMarker,
    required this.hasLottiContent,
    required this.hasName,
    required this.createdAtSlot,
    required this.memberCountSlot,
  });

  final bool encrypted;
  final bool publicRoom;
  final bool hasStateMarker;
  final bool hasLottiContent;
  final bool hasName;
  final int createdAtSlot;
  final int memberCountSlot;

  bool get included =>
      encrypted && !publicRoom && (hasStateMarker || hasLottiContent);

  int get confidence {
    var score = 0;
    if (hasStateMarker) score += 10;
    if (hasLottiContent) score += 5;
    return score;
  }

  int? get memberCount => memberCountSlot == 0 ? null : memberCountSlot;

  int get expectedMemberCount => memberCount ?? 1;

  JoinRules get joinRules => publicRoom ? JoinRules.public : JoinRules.invite;

  String nameAt(int index) => hasName ? 'Generated room $index' : '';

  DateTime? createdAtAt(int index) {
    if (createdAtSlot == 0) return null;
    return DateTime.utc(2024).add(
      Duration(days: createdAtSlot + index * 10),
    );
  }

  @override
  String toString() {
    return 'GeneratedRoomDiscoveryCase('
        'encrypted: $encrypted, '
        'publicRoom: $publicRoom, '
        'hasStateMarker: $hasStateMarker, '
        'hasLottiContent: $hasLottiContent, '
        'hasName: $hasName, '
        'createdAtSlot: $createdAtSlot, '
        'memberCountSlot: $memberCountSlot'
        ')';
  }
}

class GeneratedRoomDiscoveryScenario {
  const GeneratedRoomDiscoveryScenario(this.rooms);

  final List<GeneratedRoomDiscoveryCase> rooms;

  String roomIdAt(int index) => '!generated-$index:server';

  Set<String> get expectedRoomIds => {
    for (var i = 0; i < rooms.length; i++)
      if (rooms[i].included) roomIdAt(i),
  };

  @override
  String toString() => 'GeneratedRoomDiscoveryScenario($rooms)';
}

extension AnyGeneratedRoomDiscoveryScenario on glados.Any {
  glados.Generator<GeneratedRoomDiscoveryCase> get roomDiscoveryCase =>
      glados.CombinableAny(this).combine7(
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 5),
        (
          bool encrypted,
          bool publicRoom,
          bool hasStateMarker,
          bool hasLottiContent,
          bool hasName,
          int createdAtSlot,
          int memberCountSlot,
        ) => GeneratedRoomDiscoveryCase(
          encrypted: encrypted,
          publicRoom: publicRoom,
          hasStateMarker: hasStateMarker,
          hasLottiContent: hasLottiContent,
          hasName: hasName,
          createdAtSlot: createdAtSlot,
          memberCountSlot: memberCountSlot,
        ),
      );

  glados.Generator<GeneratedRoomDiscoveryScenario> get roomDiscoveryScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(1, 13, roomDiscoveryCase)
          .map(GeneratedRoomDiscoveryScenario.new);
}

MockRoom createMockRoom({
  required String id,
  required bool encrypted,
  required JoinRules joinRules,
  String name = '',
  bool hasLottiStateMarker = false,
  bool hasLottiContent = false,
  DateTime? createdAt,
  int? memberCount = 1,
  bool useStrippedStateEvent = false,
}) {
  final room = MockRoom();
  final summary = MockRoomSummary();
  final timeline = MockTimeline();

  when(() => room.id).thenReturn(id);
  when(() => room.name).thenReturn(name);
  when(() => room.encrypted).thenReturn(encrypted);
  when(() => room.joinRules).thenReturn(joinRules);
  when(() => room.summary).thenReturn(summary);
  when(() => summary.mJoinedMemberCount).thenReturn(memberCount);

  // State marker
  if (hasLottiStateMarker) {
    final stateEvent = MockStrippedStateEvent();
    when(() => room.getState(lottiSyncRoomStateType)).thenReturn(stateEvent);
  } else {
    when(() => room.getState(lottiSyncRoomStateType)).thenReturn(null);
  }

  // Creation time
  if (createdAt != null) {
    final createEvent = MockEvent();
    when(() => createEvent.originServerTs).thenReturn(createdAt);
    when(() => room.getState('m.room.create')).thenReturn(createEvent);
  } else if (useStrippedStateEvent) {
    final strippedEvent = MockStrippedStateEvent();
    when(() => room.getState('m.room.create')).thenReturn(strippedEvent);
  } else {
    when(() => room.getState('m.room.create')).thenReturn(null);
  }

  // Timeline with content
  if (hasLottiContent) {
    final syncEvent = createMockEvent(
      content: {'msgtype': syncMessageType, 'body': 'test'},
    );
    when(() => timeline.events).thenReturn([syncEvent]);
  } else {
    when(() => timeline.events).thenReturn([]);
  }

  when(
    () => room.getTimeline(limit: any(named: 'limit')),
  ).thenAnswer((_) async => timeline);

  return room;
}

/// Creates a mock room with specific events for content detection testing.
MockRoom createMockRoomWithEvents({
  required String id,
  required bool encrypted,
  required JoinRules joinRules,
  required List<Event> events,
}) {
  final room = MockRoom();
  final summary = MockRoomSummary();
  final timeline = MockTimeline();

  when(() => room.id).thenReturn(id);
  when(() => room.name).thenReturn('');
  when(() => room.encrypted).thenReturn(encrypted);
  when(() => room.joinRules).thenReturn(joinRules);
  when(() => room.summary).thenReturn(summary);
  when(() => summary.mJoinedMemberCount).thenReturn(1);
  when(() => room.getState(lottiSyncRoomStateType)).thenReturn(null);
  when(() => room.getState('m.room.create')).thenReturn(null);
  when(() => timeline.events).thenReturn(events);
  when(
    () => room.getTimeline(limit: any(named: 'limit')),
  ).thenAnswer((_) async => timeline);

  return room;
}

/// Creates a mock event with specified content.
MockEvent createMockEvent({
  required Map<String, dynamic> content,
  String text = '',
}) {
  final event = MockEvent();
  when(() => event.content).thenReturn(content);
  when(() => event.text).thenReturn(text);
  return event;
}
