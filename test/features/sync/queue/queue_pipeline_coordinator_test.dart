import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'test_utils.dart';

part 'queue_pipeline_coordinator_cases/bridge_recovery.dart';
part 'queue_pipeline_coordinator_cases/catch_up_claims.dart';
part 'queue_pipeline_coordinator_cases/gap_recovery.dart';
part 'queue_pipeline_coordinator_cases/history_collection.dart';
part 'queue_pipeline_coordinator_cases/lifecycle.dart';
part 'queue_pipeline_coordinator_cases/live_ingress.dart';
part 'queue_pipeline_coordinator_cases/live_ingress_properties.dart';
part 'queue_pipeline_coordinator_cases/live_seal.dart';
part 'queue_pipeline_coordinator_cases/pipeline_integration.dart';
part 'queue_pipeline_coordinator_cases/reconnect_attachments.dart';
part 'queue_pipeline_coordinator_cases/reconnect_routing.dart';
part 'queue_pipeline_coordinator_cases/resurrection.dart';
part 'queue_pipeline_coordinator_cases/sync_signals.dart';
part 'queue_pipeline_coordinator_cases/test_doubles.dart';
part 'queue_pipeline_coordinator_cases/test_setup.dart';

void main() {
  final setup = _QueueCoordinatorTestSetup()
    ..registerLifecycle()
    ..registerStart()
    ..registerCatchUpClaims()
    ..registerLiveIngress()
    ..registerStartUnwind()
    ..registerLiveIngressProperties()
    ..registerLiveSeal()
    ..registerShutdown()
    ..registerBridgeFacade()
    ..registerStartErrors()
    ..registerSyncSignals()
    ..registerEnqueueFailure()
    ..registerHistoryCollection()
    ..registerQueueFacade()
    ..registerSyncSignalErrors()
    ..registerPendingShutdownAndDefaultLifecycle()
    ..registerStartupRecoveryAndDrainDeadlines()
    ..registerBridgeRecovery()
    ..registerResurrection()
    ..registerAttachmentIngestor()
    ..registerSelfEchoSuppression()
    ..registerResurrectionErrors()
    ..registerGapRecovery();
  group('reconnect forward-walk dispatch (Option B)', () {
    setup
      ..registerReconnectRouting()
      ..registerReconnectAttachments()
      ..registerReconnectDispatchProperties();
  });
  setup.registerPipelineIntegration();
}
