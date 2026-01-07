import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/repository/whats_new_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'whats_new_controller.g.dart';

/// Provider for the [WhatsNewService].
@riverpod
WhatsNewService whatsNewService(Ref ref) {
  return WhatsNewService();
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

    // Fetch the index of available releases
    final releases = await service.fetchIndex();

    if (releases == null || releases.isEmpty) {
      return const WhatsNewState();
    }

    // Find all unseen releases (releases are already sorted by date descending)
    final unseenReleases = <WhatsNewContent>[];
    for (final release in releases) {
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

    // Refresh the state
    ref.invalidateSelf();
  }
}
