import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

typedef DemoMediaHydrationLaunch = void Function(Future<void> hydration);

/// Starts best-effort R2 media reconciliation for the active demo world.
///
/// A guest profile is not assumed to be the product demo: the seed manifest
/// is the discriminator. The manifest also filters the current catalog to
/// image entities that this particular seed version actually wrote, so a
/// stale demo resumed to protect user-created work does not download assets
/// for entities it does not contain.
///
/// The background work first runs [backfillDemoThumbHashes] over the same
/// images, so a world seeded before the stand-ins existed gets them without
/// a reseed, then hydrates.
Future<void> registerDemoMediaHydration({
  required GetIt serviceLocator,
  required ProfileContext profile,
  required List<DemoMediaAsset> catalog,
  @visibleForTesting DemoMediaDownload? download,
  @visibleForTesting http.Client? client,
  @visibleForTesting Future<Set<String>> Function()? activeJournalIds,
  @visibleForTesting void Function()? closeDownloader,
  @visibleForTesting DemoMediaHydrationLaunch? launch,
}) async {
  if (!profile.isGuest) return;

  final logger = serviceLocator<DomainLogger>();
  DemoSeedManifest? manifest;
  try {
    manifest = await DemoSeedManifest.read(profile.root);
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.general,
      error,
      stackTrace: stackTrace,
      subDomain: 'demoMediaManifest',
      message: 'Unable to read demo media manifest',
    );
    return;
  }
  if (manifest == null) return;

  Set<String> presentIds;
  try {
    final readActiveJournalIds =
        activeJournalIds ??
        () async {
          return (await serviceLocator<JournalDb>()
                  .allNonDeletedJournalEntityIds())
              .toSet();
        };
    presentIds = await readActiveJournalIds();
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.general,
      error,
      stackTrace: stackTrace,
      subDomain: 'demoMediaJournal',
      message: 'Unable to inspect demo media entities',
    );
    return;
  }

  final seededIds = manifest.seededJournalIds.toSet();
  final requiredAssets = [
    for (final asset in catalog)
      if (seededIds.contains(asset.id) && presentIds.contains(asset.id)) asset,
  ];
  if (requiredAssets.isEmpty) return;

  void onError(
    DemoMediaAsset asset,
    Object error,
    StackTrace stackTrace,
  ) {
    logger.error(
      LogDomain.general,
      error,
      stackTrace: stackTrace,
      subDomain: 'demoMediaHydration',
      message: 'Unable to hydrate ${asset.fileName}',
    );
  }

  final hydrator = download == null
      ? DemoMediaHydrator.network(
          root: profile.root,
          assets: requiredAssets,
          onError: onError,
          client: client,
        )
      : DemoMediaHydrator(
          root: profile.root,
          assets: requiredAssets,
          download: download,
          closeDownloader: closeDownloader,
          onError: onError,
        );
  serviceLocator.registerSingleton<DemoMediaHydrator>(
    hydrator,
    dispose: (service) => service.dispose(),
  );
  final hydration = backfillDemoThumbHashes(
    journalDb: serviceLocator<JournalDb>(),
    updateNotifications: serviceLocator<UpdateNotifications>(),
    logger: logger,
    assets: requiredAssets,
  ).then((_) => hydrator.hydrate()).then((_) {});
  (launch ?? unawaited)(hydration);
}

/// Writes the catalog's ThumbHash into seeded images that predate the field.
///
/// A world seeded before `ImageData.thumbHash` existed resumes as it is — a
/// stale manifest never wipes a world — and would show empty slots for
/// anything still downloading. Filling the field in place, once and only
/// where it is null, gives such a world its stand-ins without a wipe or a
/// re-download. Each rewritten id is announced through [updateNotifications]
/// so a slot already on screen picks its stand-in up. Failures are logged
/// per image and never hold up the downloads that follow.
///
/// Returns how many images were rewritten.
@visibleForTesting
Future<int> backfillDemoThumbHashes({
  required JournalDb journalDb,
  required UpdateNotifications updateNotifications,
  required DomainLogger logger,
  required List<DemoMediaAsset> assets,
}) async {
  final assetsById = {for (final asset in assets) asset.id: asset};
  final List<JournalEntity> entities;
  try {
    entities = await journalDb.getJournalEntitiesForIds(
      assetsById.keys.toSet(),
    );
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.general,
      error,
      stackTrace: stackTrace,
      subDomain: 'demoMediaThumbHash',
      message: 'Unable to read demo images for the ThumbHash backfill',
    );
    return 0;
  }

  var written = 0;
  for (final entity in entities) {
    final hash = assetsById[entity.id]?.thumbHash;
    if (entity is! JournalImage ||
        hash == null ||
        entity.data.thumbHash != null) {
      continue;
    }
    try {
      final result = await journalDb.updateJournalEntity(
        entity.copyWith(data: entity.data.copyWith(thumbHash: hash)),
      );
      if (!result.applied) continue;
      updateNotifications.notify(entity.affectedIds);
      written++;
    } catch (error, stackTrace) {
      logger.error(
        LogDomain.general,
        error,
        stackTrace: stackTrace,
        subDomain: 'demoMediaThumbHash',
        message: 'Unable to backfill the ThumbHash of ${entity.data.imageFile}',
      );
    }
  }
  return written;
}
