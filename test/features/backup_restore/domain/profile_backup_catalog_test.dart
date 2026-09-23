import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_startup.dart';

void main() {
  group('ProfileBackupCatalog', () {
    test('enumerates every SQLite store with a stable identity', () {
      final sqliteStores = ProfileBackupCatalog.stores
          .where((store) => store.kind == BackupStoreKind.sqliteDatabase)
          .toList(growable: false);

      expect(
        {for (final store in sqliteStores) store.relativePath: store.id},
        {
          'db.sqlite': 'journal',
          'sync.sqlite': 'sync',
          'agent.sqlite': 'agents',
          'editor_drafts_db.sqlite': 'editor-drafts',
          'ai_consumption.sqlite': 'ai-consumption',
          'settings.sqlite': 'settings',
          'fts5_db.sqlite': 'full-text-index',
          'notifications.sqlite': 'notifications',
          'onboarding_metrics.sqlite': 'onboarding-metrics',
          'ai_config.sqlite': 'ai-config',
          'day_processing.sqlite': 'day-processing',
          'matrix/lotti_sync.db': 'matrix-sdk',
        },
      );
      expect(
        sqliteStores.map((store) => store.id).toSet(),
        hasLength(sqliteStores.length),
      );
    });

    test('distinguishes protected authoritative and rebuildable stores', () {
      expect(
        ProfileBackupCatalog.classify('ai_config.sqlite'),
        isA<BackupPathDecision>()
            .having(
              (decision) => decision.treatment,
              'treatment',
              BackupPathTreatment.include,
            )
            .having(
              (decision) => decision.sensitivity,
              'sensitivity',
              BackupSensitivity.credentials,
            ),
      );
      expect(
        ProfileBackupCatalog.classify('matrix/lotti_sync.db'),
        isA<BackupPathDecision>()
            .having(
              (decision) => decision.storeId,
              'storeId',
              'matrix-sdk',
            )
            .having(
              (decision) => decision.sensitivity,
              'sensitivity',
              BackupSensitivity.credentials,
            ),
      );
      expect(
        ProfileBackupCatalog.classify('fts5_db.sqlite').treatment,
        BackupPathTreatment.rebuild,
      );
      expect(
        ProfileBackupCatalog.classify(
          'objectbox_embeddings_sharded/category/data.mdb',
        ).treatment,
        BackupPathTreatment.rebuild,
      );
      expect(
        ProfileBackupCatalog.classify(
          'audio_waveforms/ab/entry.json',
        ).treatment,
        BackupPathTreatment.rebuild,
      );
    });

    test('includes opaque media and sidecars by default', () {
      for (final path in [
        'audio/2026-08-06/recording.m4a',
        'images/2026-08-06/photo.jpg',
        'agent_entities/agent.json',
        'agent_links/link.json',
        'notifications/notification.json',
        'outbox_bundles/bundle.json',
        'future_feature/new_store.bin',
      ]) {
        expect(
          ProfileBackupCatalog.classify(path),
          isA<BackupPathDecision>()
              .having(
                (decision) => decision.treatment,
                '$path treatment',
                BackupPathTreatment.include,
              )
              .having(
                (decision) => decision.sensitivity,
                '$path sensitivity',
                BackupSensitivity.personal,
              ),
        );
      }
    });

    test('excludes device-global, diagnostic, and recursive content', () {
      for (final path in [
        'profiles.json',
        'profiles.json.tmp.123.456.media',
        'profiles.json.bak.123',
        'guest_profiles/demo/db.sqlite',
        'backup/db.2026-08-06.sqlite',
        'logs/general-2026-08-06.log',
        'logs/general.log.tmp.123.456.media',
        '$legacyDayProcessingOutboxDirectory/job.json.tmp.1737000000000000.4242.media',
        // A restore in progress, including the databases it is moving.
        '$profileRestoreWorkDirectoryName/incoming-1/payload/db.sqlite',
        '$profileRestoreWorkDirectoryName/previous-1/db.sqlite-wal',
        '$profileRestoreWorkDirectoryName/restore-journal.json',
      ]) {
        expect(
          ProfileBackupCatalog.classify(path).treatment,
          BackupPathTreatment.exclude,
          reason: path,
        );
      }
    });

    test('rejects SQLite companions and interrupted atomic writes', () {
      for (final path in [
        'db.sqlite-wal',
        'sync.sqlite-shm',
        'agent.sqlite-journal',
        'future_store.sqlite-wal',
        'agent_entities/id.json.tmp.123.456.media',
        'agent_entities/id.json.bak.123',
      ]) {
        expect(
          ProfileBackupCatalog.classify(path).treatment,
          BackupPathTreatment.reject,
          reason: path,
        );
      }
    });

    test('refuses non-canonical or escaping paths', () {
      for (final path in [
        '',
        '/db.sqlite',
        '../db.sqlite',
        'images/../db.sqlite',
        r'images\entry.jpg',
        'images//entry.jpg',
        'C:/db.sqlite',
      ]) {
        expect(
          () => ProfileBackupCatalog.classify(path),
          throwsFormatException,
          reason: path,
        );
      }
    });
  });

  group('path properties', () {
    glados.Glados(
      glados.any.backupPath,
      glados.ExploreConfig(numRuns: 500),
    ).test(
      'a path is accepted exactly when it is canonical and relative',
      (path) {
        final segments = path.split('/');
        final canonical =
            path.isNotEmpty &&
            !path.contains(r'\') &&
            !path.contains(':') &&
            segments.every((s) => s.isNotEmpty && s != '.' && s != '..');

        if (canonical) {
          ProfileBackupCatalog.validateRelativePath(path);
          // A valid path always has a policy, and always the same one.
          final decision = ProfileBackupCatalog.classify(path);
          final again = ProfileBackupCatalog.classify(path);
          expect(
            (decision.storeId, decision.treatment, decision.kind),
            (again.storeId, again.treatment, again.kind),
          );
          expect(
            {
              ...ProfileBackupCatalog.stores.map((s) => s.id),
              'sqlite-companion',
              'interrupted-atomic-write',
            },
            contains(decision.storeId),
          );
        } else {
          expect(
            () => ProfileBackupCatalog.validateRelativePath(path),
            throwsFormatException,
          );
          expect(
            () => ProfileBackupCatalog.classify(path),
            throwsFormatException,
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.AnyUtils(glados.any).choose(
        ProfileBackupCatalog.stores
            .where((store) => store.relativePath.isNotEmpty)
            .toList(),
      ),
      glados.any.backupPath,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'a store’s own path, and for a directory anything under it, is its own',
      (store, suffix) {
        expect(
          ProfileBackupCatalog.classify(store.relativePath).storeId,
          store.id,
        );
        final nested = '${store.relativePath}/$suffix';
        final isCanonical =
            !nested.contains(r'\') &&
            !nested.contains(':') &&
            nested
                .split('/')
                .every(
                  (s) => s.isNotEmpty && s != '.' && s != '..',
                );
        if (store.kind == BackupStoreKind.directory &&
            isCanonical &&
            store.treatment != BackupPathTreatment.include) {
          // Excluded and rebuilt trees swallow everything below them,
          // companions and temporaries included.
          expect(ProfileBackupCatalog.classify(nested).storeId, store.id);
        }
      },
      tags: 'glados',
    );
  });
}

extension _AnyBackupPath on glados.Any {
  /// Up to four segments from a pool mixing ordinary names with every kind
  /// of segment the validator must refuse.
  glados.Generator<String> get backupPath =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.ListAnys(this).listWithLengthInRange(
          0,
          5,
          glados.AnyUtils(this).choose(const [
            'images',
            'audio',
            'db.sqlite',
            'db.sqlite-wal',
            'entry.jpg',
            'x.bak.3',
            'matrix',
            'a',
            'b',
            '',
            '.',
            '..',
            'c:d',
            r'e\f',
            '.hidden',
            '...',
          ]),
        ),
        (bool leadingSlash, List<String> segments) =>
            '${leadingSlash ? '/' : ''}${segments.join('/')}',
      );
}
