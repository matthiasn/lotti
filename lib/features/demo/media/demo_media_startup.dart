import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
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
Future<void> registerDemoMediaHydration({
  required GetIt serviceLocator,
  required ProfileContext profile,
  required List<DemoMediaAsset> catalog,
  @visibleForTesting DemoMediaDownload? download,
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

  final seededIds = manifest.seededJournalIds.toSet();
  final requiredAssets = [
    for (final asset in catalog)
      if (seededIds.contains(asset.id)) asset,
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
  final hydration = hydrator.hydrate().then((_) {});
  (launch ?? unawaited)(hydration);
}
