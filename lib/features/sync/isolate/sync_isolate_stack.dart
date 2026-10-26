import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/instrumentation/sync_cost_meter.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host_client.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/sync_attachment_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_recovery.dart';
import 'package:lotti/features/sync/matrix/sync_event_trust.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message_too_large_exception.dart';
import 'package:lotti/features/sync/models/sync_verification.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/sync_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart' show Client;

/// The Matrix stack inside the sync isolate (ADR 0142, step 4b): the same
/// `MatrixService` the UI isolate ran in-process, composed over the worker's
/// own `sync.sqlite` connection and the host-answered stores, answering the
/// `SyncService` commands and reporting what the UI used to read off the
/// client as events.
///
/// [compose] builds the production stack; the constructor takes the pieces,
/// so a test drives the command handling against doubles without a client.
class SyncIsolateStack {
  SyncIsolateStack({
    required MatrixService service,
    required AttachmentIndex attachmentIndex,
    required SyncDescriptorRecovery descriptorRecovery,
    required SyncAttachmentFetcher attachmentFetcher,
    required void Function(SyncIsolateEvent event) emit,
    StreamController<List<ConnectivityResult>>? connectivity,
    Future<void> Function()? disposeExtras,
  }) : this._(
         service,
         attachmentIndex,
         descriptorRecovery,
         attachmentFetcher,
         emit,
         connectivity ?? StreamController<List<ConnectivityResult>>.broadcast(),
         disposeExtras,
       );

  SyncIsolateStack._(
    this.service,
    this.attachmentIndex,
    this._descriptorRecovery,
    this._attachmentFetcher,
    this._emit,
    this._connectivity,
    this._disposeExtras,
  ) {
    service.queueCoordinator
      ..onBridgeStarted = () {
        _emit(const SyncIsolateBridgeChanged(inFlight: true));
      }
      ..onBridgeCompleted = () {
        _emit(const SyncIsolateBridgeChanged(inFlight: false));
      };
    _subscriptions.addAll([
      service.loginStateChanges.listen((state) {
        _emit(SyncIsolateLoginStateChanged(state));
        _emit(_session());
        _emitUnverified();
      }),
      service.syncRoomIdChanges.listen(
        (roomId) => _emit(SyncIsolateRoomIdChanged(roomId)),
      ),
      service.outgoingVerifications.listen(
        (state) => _verification(SyncIsolateVerificationStream.outgoing, state),
      ),
      service.incomingVerifications.listen(
        (state) => _verification(SyncIsolateVerificationStream.incoming, state),
      ),
      service.incomingVerificationRequests.listen(
        (state) => _verification(SyncIsolateVerificationStream.request, state),
      ),
      service.stats.listen((stats) => _emit(SyncIsolateStatsChanged(stats))),
      attachmentIndex.pathRecorded.listen((path) {
        final descriptor = attachmentIndex.find(path);
        if (descriptor != null) {
          _emit(SyncIsolateAttachmentRecorded(descriptor));
        }
      }),
      // Admission and the bridge write the queue on this connection; the UI
      // isolate's depth streams see those writes only through the relay.
      service.inboundQueue.depthChanges.listen(
        (_) => _emit(const SyncIsolateTablesChanged(inboundQueueTables)),
      ),
    ]);
  }

  /// Composes the production stack for [config]: initialises the crypto
  /// bindings for this isolate, opens the SDK database under the documents
  /// directory and wires client, gateway, session and room managers,
  /// admission and bridge (producer-only), ingestion and the sender over the
  /// host-answered stores. [initCrypto] and [createClient] are injectable
  /// for tests that have no native libraries.
  static Future<SyncIsolateStack> compose({
    required SyncIsolateConfig config,
    required SyncDatabase db,
    required SyncIsolateHostClient host,
    required DomainLogger logger,
    required void Function(SyncIsolateEvent event) emit,
    Future<void> Function() initCrypto = vod.init,
    Future<Client> Function(Directory documentsDirectory)? createClient,
  }) async {
    // vodozemac is bound per isolate: the UI isolate's init does not count.
    await initCrypto();
    final documents = Directory(config.documentsPath);
    final client =
        await (createClient?.call(documents) ??
            createMatrixClient(documentsDirectory: documents));
    final costMeter = SyncCostMeter(logger: logger)
      ..observeSdkSync(client.onSyncStatus.stream)
      ..start();
    final registry = SentEventRegistry();
    final gateway = MatrixSdkGateway(
      client: client,
      sentEventRegistry: registry,
    );
    final settings = HostKeyValueStore(host);
    final sender = MatrixMessageSender(
      loggingService: logger,
      journalDb: HostPayloadSource(host),
      documentsDirectory: documents,
      sentEventRegistry: registry,
      vectorClockService: HostIdSource(host),
      domainLogger: logger,
    );
    final index = AttachmentIndex(logging: logger, verboseLogging: false);
    final trust = SyncEventTrust(syncDb: db, logging: logger);
    final descriptorFetcher = MatrixDescriptorFetcher.forClient(client);
    final attachmentFetcher = MatrixAttachmentFetcher(
      events: descriptorFetcher,
    );
    final roomManager = SyncRoomManager(
      gateway: gateway,
      settingsDb: settings,
      loggingService: logger,
    );
    final sessionManager =
        MatrixSessionManager(
            gateway: gateway,
            roomManager: roomManager,
            loggingService: logger,
          )
          ..matrixConfig = config.matrixConfig
          ..deviceDisplayName = config.deviceDisplayName;
    final ingestor = AttachmentIngestor(
      documentsDirectory: documents,
      verboseLogging: false,
      localVcDominates: (relativePath, incomingVectorClock) => host.ask<bool>(
        SyncIsolateHostLocalVcDominates(
          relativePath: relativePath,
          incomingVectorClock: incomingVectorClock,
        ),
      ),
    );
    // Producer-only: no apply step here, the UI isolate drains the queue.
    final coordinator = QueuePipelineCoordinator(
      syncDb: db,
      settingsDb: settings,
      sessionManager: sessionManager,
      roomManager: roomManager,
      activityGate: null,
      logging: logger,
      syncEventTrust: trust,
      attachmentIndex: index,
      attachmentIngestor: ingestor,
      sentEventRegistry: registry,
      costMeter: costMeter,
    );
    // Broadcast: closing it must not wait for a listener the service may
    // already have dropped.
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    final service = MatrixService(
      gateway: gateway,
      loggingService: logger,
      messageSender: sender,
      settingsDb: settings,
      queueCoordinator: coordinator,
      collectSyncMetrics: config.collectSyncMetrics,
      roomManager: roomManager,
      sessionManager: sessionManager,
      connectivityStream: connectivity.stream,
    );
    return SyncIsolateStack(
      service: service,
      attachmentIndex: index,
      descriptorRecovery: TrustedDescriptorRecovery(
        fetcher: descriptorFetcher,
        trust: trust,
        logging: logger,
      ),
      attachmentFetcher: attachmentFetcher,
      emit: emit,
      connectivity: connectivity,
      disposeExtras: () async {
        await costMeter.dispose();
        await index.dispose();
      },
    );
  }

  final MatrixService service;
  final AttachmentIndex attachmentIndex;
  final SyncDescriptorRecovery _descriptorRecovery;
  final SyncAttachmentFetcher _attachmentFetcher;
  final void Function(SyncIsolateEvent event) _emit;
  final StreamController<List<ConnectivityResult>> _connectivity;
  final Future<void> Function()? _disposeExtras;
  final _subscriptions = <StreamSubscription<Object?>>[];

  void _verification(
    SyncIsolateVerificationStream stream,
    SyncVerificationState state,
  ) {
    _emit(SyncIsolateVerificationChanged(stream: stream, state: state));
    // A ceremony that ended changes the roster; one that did not costs a
    // cache read.
    if (!state.isPending) _emitUnverified();
  }

  /// The roster the proxy answers `getUnverifiedDevices` from.
  void _emitUnverified() => _emit(
    SyncIsolateUnverifiedDevicesChanged(service.getUnverifiedDevices()),
  );

  SyncIsolateSessionChanged _session() => SyncIsolateSessionChanged(
    isLoggedIn: service.isLoggedIn(),
    ownUserId: service.ownUserId,
    ownDeviceId: service.ownDeviceId,
    homeserverHost: service.homeserverHost,
  );

  /// What a late-starting proxy reads first.
  SyncIsolateSnapshot snapshot() => SyncIsolateSnapshot(
    isLoggedIn: service.isLoggedIn(),
    ownUserId: service.ownUserId,
    ownDeviceId: service.ownDeviceId,
    homeserverHost: service.homeserverHost,
    syncRoomId: service.syncRoomId,
    outgoingVerification: service.outgoingVerification,
    incomingVerification: service.incomingVerification,
    stats: MatrixStats(
      sentCount: service.sentCount,
      messageCounts: Map<String, int>.of(service.messageCounts),
    ),
    isBridgeInFlight: service.queueCoordinator.isBridgeInFlight,
  );

  /// Answers a `SyncService` command. The worker handles liveness and the
  /// queue hand-off itself and never passes those here.
  Future<Object?> handle(SyncIsolateCommand command) async {
    switch (command) {
      case SyncIsolateInitStack():
        await service.init();
        _emit(_session());
        _emitUnverified();
        return null;
      case SyncIsolateConfigure(:final config):
        if (config == null) {
          await service.deleteConfig();
        } else {
          await service.setConfig(config);
        }
        return null;
      case SyncIsolateLogin(:final waitForLifecycle):
        final loggedIn = await service.login(
          waitForLifecycle: waitForLifecycle,
        );
        _emit(_session());
        _emitUnverified();
        return loggedIn;
      case SyncIsolateConnect():
        final connected = await service.connect();
        _emit(_session());
        _emitUnverified();
        return connected;
      case SyncIsolateLogout():
        await service.logout();
        _emit(_session());
        return null;
      case SyncIsolateChangePassword(:final oldPassword, :final newPassword):
        await service.changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
        );
        return null;
      case SyncIsolateConnectivityChanged(:final online):
        _connectivity.add([
          if (online) ConnectivityResult.wifi else ConnectivityResult.none,
        ]);
        return null;
      case SyncIsolateGetRoom():
        return service.getRoom();
      case SyncIsolateJoinRoom(:final roomId):
        return service.joinRoom(roomId);
      case SyncIsolateCreateRoom():
        return service.createRoom();
      case SyncIsolateFindSyncRoom():
        return service.findSyncRoom();
      case SyncIsolateSaveRoom(:final roomId):
        await service.saveRoom(roomId);
        return null;
      case SyncIsolateClearPersistedRoom():
        await service.clearPersistedRoom();
        return null;
      case SyncIsolatePublishRotationProof(
        :final roomId,
        :final bundleId,
        :final challenge,
      ):
        await service.publishRotationProof(
          roomId: roomId,
          bundleId: bundleId,
          challenge: challenge,
        );
        return null;
      case SyncIsolateGetUnverifiedDevices():
        final devices = service.getUnverifiedDevices();
        _emit(SyncIsolateUnverifiedDevicesChanged(devices));
        return devices;
      case SyncIsolateGetSyncDevices():
        return service.getSyncDevices();
      case SyncIsolateDeleteDevice(:final deviceId, :final reauthPassword):
        await service.deleteDeviceById(
          deviceId,
          reauthPassword: reauthPassword,
        );
        return null;
      case SyncIsolateVerifyDevice(:final userId, :final deviceId):
        await service.verifyDevice(userId: userId, deviceId: deviceId);
        return null;
      case SyncIsolateVerificationAction(:final kind, :final id):
        switch (kind) {
          case SyncIsolateVerificationActionKind.accept:
            await service.acceptVerification(id);
          case SyncIsolateVerificationActionKind.acceptEmoji:
            await service.acceptEmojiVerification(id);
          case SyncIsolateVerificationActionKind.cancel:
            await service.cancelVerification(id);
          case SyncIsolateVerificationActionKind.handOffOutgoingTo:
            await service.handOffOutgoingVerificationTo(id);
        }
        return null;
      case SyncIsolateSendMessage(:final message, :final roomId):
        return service.sendMatrixMsg(message, myRoomId: roomId);
      case SyncIsolateGetSyncMetrics():
        return service.getSyncMetrics();
      case SyncIsolateGetDiagnosticsText():
        return service.getSyncDiagnosticsText();
      case SyncIsolateGetDiagnosticInfo():
        return service.getDiagnosticInfo();
      case SyncIsolateForceRescan(:final includeCatchUp):
        await service.forceRescan(includeCatchUp: includeCatchUp);
        return null;
      case SyncIsolateRetryNow():
        await service.retryNow();
        return null;
      case SyncIsolateTriggerBridge():
        await service.queueCoordinator.triggerBridge();
        return null;
      case SyncIsolateMaybeStartGapRecovery():
        service.queueCoordinator.maybeStartGapRecovery();
        return null;
      case SyncIsolateRetrySkipped():
        return service.inboundQueue.resurrectAll();
      case SyncIsolateJournalChanged():
        await service.inboundQueue.resurrectByReason('missingBase');
        return null;
      case SyncIsolateRecoverDescriptor(:final roomId, :final eventId):
        return _descriptorRecovery.recover(roomId: roomId, eventId: eventId);
      case SyncIsolateDownloadAttachment(
        :final descriptor,
        :final pathForError,
      ):
        return _attachmentFetcher.download(
          descriptor,
          pathForError: pathForError,
        );
      case SyncIsolatePurgeAttachment(:final descriptor):
        return _attachmentFetcher.purgeCached(descriptor);
      case SyncIsolateGetSnapshot():
        return snapshot();
      case SyncIsolatePing() ||
          SyncIsolateShutdown() ||
          SyncIsolateLeaseEntries() ||
          SyncIsolateSettleEntries():
        throw StateError("${command.runtimeType} is the worker's to answer");
    }
  }

  /// Stops the stack: the service drains and stops its coordinator, the
  /// session and room managers go, then the client.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await service.dispose();
    await _connectivity.close();
    await _disposeExtras?.call();
  }

  /// The failure a caught [error] crosses the port as, naming the exception
  /// types the caller acts on so the proxy can rethrow them as themselves.
  static SyncIsolateFailure failureFor(
    SyncIsolateCommand command,
    Object error,
  ) {
    final (thrown, detail) = switch (error) {
      SyncMessageTooLargeException(:final detail, :final inlineBody) => (
        SyncIsolateThrown.messageTooLarge,
        inlineBody ? '$detail\n$inlineBodyMarker' : detail,
      ),
      SyncReauthRequiredException(:final message) => (
        SyncIsolateThrown.reauthRequired,
        message,
      ),
      FileSystemException(:final path) => (
        SyncIsolateThrown.fileSystem,
        path,
      ),
      StateError() => (SyncIsolateThrown.state, null),
      _ => (SyncIsolateThrown.none, null),
    };
    return SyncIsolateFailure(
      SyncIsolateErrorCode.failed,
      '${command.runtimeType}: $error',
      thrown: thrown,
      detail: detail,
    );
  }

  /// Appended to a too-large failure's detail when the limit hit was the
  /// inline body's, so the proxy rebuilds the exception's `inlineBody`.
  static const inlineBodyMarker = 'inlineBody';
}
