import 'package:glados/glados.dart' as glados;
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockClient extends Mock implements Client {}

typedef MockLogging = MockDomainLogger;

class MockMatrixException extends Mock implements MatrixException {}

enum GeneratedReadMarkerEventIdKind { server, localPlaceholder }

enum GeneratedReadMarkerLoginKind { loggedIn, loggedOut }

enum GeneratedReadMarkerRemoteKind { same, empty, other }

enum GeneratedReadMarkerTimelineKind {
  absent,
  candidateNewer,
  remoteNewer,
  candidateOnly,
  remoteOnly,
  throwsOnEvents,
}

enum GeneratedReadMarkerRoomOutcome {
  succeeds,
  missingUnknown,
  throwsGeneric,
}

enum GeneratedReadMarkerTimelineOutcome { succeeds, throwsGeneric }

class GeneratedReadMarkerScenario {
  const GeneratedReadMarkerScenario({
    required this.eventIdKind,
    required this.loginKind,
    required this.remoteKind,
    required this.timelineKind,
    required this.roomOutcome,
    required this.timelineOutcome,
    required this.slot,
  });

  final GeneratedReadMarkerEventIdKind eventIdKind;
  final GeneratedReadMarkerLoginKind loginKind;
  final GeneratedReadMarkerRemoteKind remoteKind;
  final GeneratedReadMarkerTimelineKind timelineKind;
  final GeneratedReadMarkerRoomOutcome roomOutcome;
  final GeneratedReadMarkerTimelineOutcome timelineOutcome;
  final int slot;

  String get eventId {
    switch (eventIdKind) {
      case GeneratedReadMarkerEventIdKind.server:
        return '\$generated-marker-$slot';
      case GeneratedReadMarkerEventIdKind.localPlaceholder:
        return 'lotti-generated-marker-$slot';
    }
  }

  String get remoteId {
    switch (remoteKind) {
      case GeneratedReadMarkerRemoteKind.same:
        return eventId;
      case GeneratedReadMarkerRemoteKind.empty:
        return '';
      case GeneratedReadMarkerRemoteKind.other:
        return '\$remote-marker-$slot';
    }
  }

  bool get hasTimeline =>
      timelineKind != GeneratedReadMarkerTimelineKind.absent;

  bool get serverAssigned =>
      eventIdKind == GeneratedReadMarkerEventIdKind.server;

  bool get loggedIn => loginKind == GeneratedReadMarkerLoginKind.loggedIn;

  bool get guardBlocksRemoteUpdate =>
      serverAssigned &&
      loggedIn &&
      remoteKind == GeneratedReadMarkerRemoteKind.other &&
      timelineKind == GeneratedReadMarkerTimelineKind.remoteNewer;

  bool get savesLocalMarker => serverAssigned;

  bool get attemptsRoomMarker =>
      serverAssigned && loggedIn && !guardBlocksRemoteUpdate;

  bool get attemptsTimelineFallback =>
      attemptsRoomMarker &&
      hasTimeline &&
      roomOutcome == GeneratedReadMarkerRoomOutcome.throwsGeneric;

  bool get logsRoomFailure =>
      attemptsRoomMarker &&
      roomOutcome == GeneratedReadMarkerRoomOutcome.throwsGeneric &&
      (!hasTimeline ||
          timelineOutcome == GeneratedReadMarkerTimelineOutcome.throwsGeneric);

  bool get logsMissingEvent =>
      attemptsRoomMarker &&
      roomOutcome == GeneratedReadMarkerRoomOutcome.missingUnknown;

  @override
  String toString() {
    return 'GeneratedReadMarkerScenario('
        'eventIdKind: $eventIdKind, '
        'loginKind: $loginKind, '
        'remoteKind: $remoteKind, '
        'timelineKind: $timelineKind, '
        'roomOutcome: $roomOutcome, '
        'timelineOutcome: $timelineOutcome, '
        'slot: $slot'
        ')';
  }
}

extension AnyGeneratedReadMarkerScenario on glados.Any {
  glados.Generator<GeneratedReadMarkerEventIdKind> get readMarkerEventIdKind =>
      glados.AnyUtils(this).choose(GeneratedReadMarkerEventIdKind.values);

  glados.Generator<GeneratedReadMarkerLoginKind> get readMarkerLoginKind =>
      glados.AnyUtils(this).choose(GeneratedReadMarkerLoginKind.values);

  glados.Generator<GeneratedReadMarkerRemoteKind> get readMarkerRemoteKind =>
      glados.AnyUtils(this).choose(GeneratedReadMarkerRemoteKind.values);

  glados.Generator<GeneratedReadMarkerTimelineKind>
  get readMarkerTimelineKind =>
      glados.AnyUtils(this).choose(GeneratedReadMarkerTimelineKind.values);

  glados.Generator<GeneratedReadMarkerRoomOutcome> get readMarkerRoomOutcome =>
      glados.AnyUtils(this).choose(GeneratedReadMarkerRoomOutcome.values);

  glados.Generator<GeneratedReadMarkerTimelineOutcome>
  get readMarkerTimelineOutcome =>
      glados.AnyUtils(this).choose(GeneratedReadMarkerTimelineOutcome.values);

  glados.Generator<GeneratedReadMarkerScenario> get readMarkerScenario =>
      glados.CombinableAny(this).combine7(
        readMarkerEventIdKind,
        readMarkerLoginKind,
        readMarkerRemoteKind,
        readMarkerTimelineKind,
        readMarkerRoomOutcome,
        readMarkerTimelineOutcome,
        glados.IntAnys(this).intInRange(0, 8),
        (
          GeneratedReadMarkerEventIdKind eventIdKind,
          GeneratedReadMarkerLoginKind loginKind,
          GeneratedReadMarkerRemoteKind remoteKind,
          GeneratedReadMarkerTimelineKind timelineKind,
          GeneratedReadMarkerRoomOutcome roomOutcome,
          GeneratedReadMarkerTimelineOutcome timelineOutcome,
          int slot,
        ) => GeneratedReadMarkerScenario(
          eventIdKind: eventIdKind,
          loginKind: loginKind,
          remoteKind: remoteKind,
          timelineKind: timelineKind,
          roomOutcome: roomOutcome,
          timelineOutcome: timelineOutcome,
          slot: slot,
        ),
      );
}
