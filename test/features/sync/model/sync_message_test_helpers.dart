import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';

// ---------------------------------------------------------------------------
// Glados helpers — top-level so they are accessible inside main()
// ---------------------------------------------------------------------------

class GeneratedThemingSelection {
  const GeneratedThemingSelection({
    required this.lightThemeName,
    required this.darkThemeName,
    required this.themeMode,
    required this.updatedAt,
    required this.status,
  });

  final String lightThemeName;
  final String darkThemeName;
  final String themeMode;
  final int updatedAt;
  final SyncEntryStatus status;

  @override
  String toString() =>
      'GeneratedThemingSelection('
      'lightThemeName: $lightThemeName, '
      'darkThemeName: $darkThemeName, '
      'themeMode: $themeMode, '
      'updatedAt: $updatedAt, '
      'status: $status'
      ')';
}

class GeneratedBackfillRequest {
  GeneratedBackfillRequest({
    required this.requesterId,
    required this.entries,
  });

  final String requesterId;
  final List<BackfillRequestEntry> entries;

  @override
  String toString() =>
      'GeneratedBackfillRequest('
      'requesterId: $requesterId, '
      'entries: $entries'
      ')';
}

class GeneratedBackfillResponse {
  const GeneratedBackfillResponse({
    required this.hostId,
    required this.counter,
    required this.deleted,
    required this.unresolvable,
    required this.payloadType,
  });

  final String hostId;
  final int counter;
  final bool deleted;
  final bool unresolvable;
  final SyncSequencePayloadType? payloadType;

  @override
  String toString() =>
      'GeneratedBackfillResponse('
      'hostId: $hostId, '
      'counter: $counter, '
      'deleted: $deleted, '
      'unresolvable: $unresolvable, '
      'payloadType: $payloadType'
      ')';
}

class GeneratedAiConfigDelete {
  const GeneratedAiConfigDelete({required this.id});

  final String id;

  @override
  String toString() => 'GeneratedAiConfigDelete(id: $id)';
}

extension AnySyncMessageGlados on glados.Any {
  glados.Generator<String> get _twoCharId =>
      glados.CombinableAny(this).combine2(
        glados.any.letterOrDigits,
        glados.any.letterOrDigits,
        (String a, String b) => '$a$b',
      );

  glados.Generator<SyncEntryStatus> get _syncEntryStatus =>
      glados.AnyUtils(this).choose(SyncEntryStatus.values);

  glados.Generator<SyncSequencePayloadType?> get _optionalPayloadType =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.AnyUtils(this).choose(SyncSequencePayloadType.values),
        (bool include, SyncSequencePayloadType t) => include ? t : null,
      );

  glados.Generator<GeneratedThemingSelection> get generatedThemingSelection =>
      glados.CombinableAny(this).combine5(
        _twoCharId,
        _twoCharId,
        glados.AnyUtils(this).choose(
          const <String>['light', 'dark', 'system'],
        ),
        glados.IntAnys(this).intInRange(0, 999999999),
        _syncEntryStatus,
        (
          String light,
          String dark,
          String mode,
          int ts,
          SyncEntryStatus status,
        ) => GeneratedThemingSelection(
          lightThemeName: light,
          darkThemeName: dark,
          themeMode: mode,
          updatedAt: ts,
          status: status,
        ),
      );

  glados.Generator<GeneratedAiConfigDelete> get generatedAiConfigDelete =>
      _twoCharId.map((String id) => GeneratedAiConfigDelete(id: id));

  glados.Generator<BackfillRequestEntry> get _backfillEntry =>
      glados.CombinableAny(this).combine2(
        _twoCharId,
        glados.IntAnys(this).intInRange(1, 9999),
        (String hostId, int counter) =>
            BackfillRequestEntry(hostId: hostId, counter: counter),
      );

  glados.Generator<GeneratedBackfillRequest> get generatedBackfillRequest =>
      glados.CombinableAny(this).combine2(
        _twoCharId,
        glados.ListAnys(this).listWithLengthInRange(0, 6, _backfillEntry),
        (String requesterId, List<BackfillRequestEntry> entries) =>
            GeneratedBackfillRequest(
              requesterId: requesterId,
              entries: entries,
            ),
      );

  glados.Generator<GeneratedBackfillResponse> get generatedBackfillResponse =>
      glados.CombinableAny(this).combine5(
        _twoCharId,
        glados.IntAnys(this).intInRange(1, 9999),
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        _optionalPayloadType,
        (
          String hostId,
          int counter,
          bool deleted,
          bool unresolvable,
          SyncSequencePayloadType? payloadType,
        ) => GeneratedBackfillResponse(
          hostId: hostId,
          counter: counter,
          deleted: deleted,
          unresolvable: unresolvable,
          payloadType: payloadType,
        ),
      );
}

SyncMessage hRoundTripSyncMessage(SyncMessage msg) => SyncMessage.fromJson(
  jsonDecode(jsonEncode(msg.toJson())) as Map<String, dynamic>,
);

/// Round-trips an agentEntity message and unwraps the decoded entity,
/// asserting the envelope type and status on the way.
AgentDomainEntity hRoundTripAgentEntity(
  SyncMessage msg, {
  required SyncEntryStatus expectStatus,
}) {
  final decoded = hRoundTripSyncMessage(msg);
  expect(decoded, isA<SyncAgentEntity>());
  final decodedMsg = decoded as SyncAgentEntity;
  expect(decodedMsg.status, expectStatus);
  return decodedMsg.agentEntity!;
}

/// Round-trips an agentLink message and unwraps the decoded link,
/// asserting the envelope type and status on the way.
AgentLink hRoundTripAgentLink(
  SyncMessage msg, {
  required SyncEntryStatus expectStatus,
}) {
  final decoded = hRoundTripSyncMessage(msg);
  expect(decoded, isA<SyncAgentLink>());
  final decodedMsg = decoded as SyncAgentLink;
  expect(decodedMsg.status, expectStatus);
  return decodedMsg.agentLink!;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
