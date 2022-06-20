import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncConfigService extends Mock implements SyncConfigService {}

class MockSyncInboxService extends Mock implements SyncInboxService {}

class MockOutboxService extends Mock implements OutboxService {}
