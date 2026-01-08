import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/repository/whats_new_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'whats_new_controller.g.dart';

/// Provider for the [WhatsNewService].
@riverpod
WhatsNewService whatsNewService(Ref ref) {
  return WhatsNewService();
}

/// Provider that checks if the What's New modal should auto-show.
///
/// Returns true when:
/// 1. This is the first app launch ever, OR
/// 2. The app version has changed since last launch
/// AND there are unseen releases to show.
///
/// Once read, this provider marks the current version as "launched"
/// so subsequent checks return false until the next version change.
@riverpod
Future<bool> shouldAutoShowWhatsNew(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  const lastLaunchedKey = 'whats_new_last_launched_version';
  final lastLaunchedVersion = prefs.getString(lastLaunchedKey);

  // Always update the stored version
  await prefs.setString(lastLaunchedKey, currentVersion);

  // If version hasn't changed, don't auto-show
  if (lastLaunchedVersion == currentVersion) {
    return false;
  }

  // First launch OR version changed - check if there are unseen releases
  final state = await ref.read(whatsNewControllerProvider.future);
  return state.hasUnseenRelease;
}

/// Controller for the "What's New" feature.
///
/// Manages fetching release content and tracking which releases
/// the user has seen using SharedPreferences.
@riverpod
class WhatsNewController extends _$WhatsNewController {
  /// Prefix for SharedPreferences keys tracking seen releases.
  static const String _seenKeyPrefix = 'whats_new_seen_';

  @override
  Future<WhatsNewState> build() async {
    final service = ref.watch(whatsNewServiceProvider);

    // Get the current app version
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // Fetch the index of available releases
    final releases = await service.fetchIndex();

    if (releases == null || releases.isEmpty) {
      return const WhatsNewState();
    }

    // Find all unseen releases that are not newer than the installed version
    final unseenReleases = <WhatsNewContent>[];
    for (final release in releases) {
      // Skip releases newer than the installed version
      if (_isNewerVersion(release.version, currentVersion)) {
        continue;
      }

      final hasSeen = await _hasSeenRelease(release.version);
      if (!hasSeen) {
        final content = await service.fetchContent(release);
        if (content != null) {
          unseenReleases.add(content);
        }
      }
    }

    return WhatsNewState(unseenContent: unseenReleases);
  }

  /// Returns true if [releaseVersion] is newer than [installedVersion].
  ///
  /// Compares semantic version strings like "0.9.804" vs "0.9.802".
  bool _isNewerVersion(String releaseVersion, String installedVersion) {
    final releaseParts = releaseVersion.split('.').map(int.tryParse).toList();
    final installedParts =
        installedVersion.split('.').map(int.tryParse).toList();

    // Compare each part of the version
    for (var i = 0; i < releaseParts.length && i < installedParts.length; i++) {
      final release = releaseParts[i] ?? 0;
      final installed = installedParts[i] ?? 0;

      if (release > installed) return true;
      if (release < installed) return false;
    }

    // If all compared parts are equal, check if release has more parts
    return releaseParts.length > installedParts.length;
  }

  /// Checks if the user has seen a specific release version.
  Future<bool> _hasSeenRelease(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_seenKeyPrefix$version') ?? false;
  }

  /// Marks all unseen releases as seen.
  ///
  /// This should be called when the user dismisses the What's New modal.
  Future<void> markAllAsSeen() async {
    final currentState = state.value;
    if (currentState == null) return;

    final prefs = await SharedPreferences.getInstance();
    for (final content in currentState.unseenContent) {
      await prefs.setBool('$_seenKeyPrefix${content.release.version}', true);
    }

    // Check if still mounted after async operations
    if (!ref.mounted) return;

    // Update the state to reflect that all releases have been seen
    state = AsyncData(
      currentState.copyWith(unseenContent: []),
    );
  }

  /// Marks a specific release as seen.
  Future<void> markAsSeen(String version) async {
    final currentState = state.value;
    if (currentState == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenKeyPrefix$version', true);

    // Check if still mounted after async operations
    if (!ref.mounted) return;

    // Remove the seen release from the state
    final remaining = currentState.unseenContent
        .where((c) => c.release.version != version)
        .toList();
    state = AsyncData(
      currentState.copyWith(unseenContent: remaining),
    );
  }

  /// Resets the seen status for all releases.
  ///
  /// Useful for testing or allowing users to view What's New again.
  Future<void> resetSeenStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_seenKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }

    // Check if still mounted after async operations
    if (!ref.mounted) return;

    // Refresh the state
    ref.invalidateSelf();
  }
}
