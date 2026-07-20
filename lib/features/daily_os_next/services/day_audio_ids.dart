import 'package:uuid/uuid.dart';

/// Stable UUIDv5 namespace name for capture-to-Activity identity.
const dailyOsAudioActivityNamespaceName =
    'https://lotti.app/namespaces/day-audio-activity';

final String _dailyOsAudioActivityNamespace = const Uuid().v5(
  Namespace.url.value,
  dailyOsAudioActivityNamespaceName,
);

/// Deterministic Activity identity shared by journal provenance, the
/// processing outbox, and the Day timeline.
String audioActivityEntryIdForSession(String recordingSessionId) =>
    const Uuid().v5(_dailyOsAudioActivityNamespace, recordingSessionId);
