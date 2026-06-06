import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';

part 'conflict_detail_cards.dart';
part 'conflict_detail_chrome.dart';
part 'conflict_detail_footer.dart';

/// Stacked vs side-by-side breakpoint for the diff cards. Below this,
/// the picker collapses to a single column and the header pill drops
/// the "fields differ" half.
const double _kStackedBreakpoint = 768;

/// Width of the colored accent stripe pinned to the leading edge of
/// each diff card.
const double _kAccentStripeWidth = 3;

/// Diameter of the small status dot rendered inside the count pill and
/// each card header. No matching design-system token; consolidated here
/// so the two call sites stay in sync.
const double _kCountPillDotSize = 5;
const double _kCardHeaderDotSize = 6;

/// Icon sizes for the back chip and the summary banner glyph. The
/// design system has no icon-size token; named here so they're not
/// re-typed at the call sites.
const double _kBackChipIconSize = 20;
const double _kSummaryIconSize = 18;

/// Picker pill height. Matches the agents-listing toolbar pill height
/// — there's no tappable-row token in the design system yet.
const double _kPickerPillHeight = 36;

enum _Side { local, remote }

/// Conflict picker page with inline word-level diffs between the local
/// and remote versions of an entry. The user picks a side (or opens
/// Edit & merge) and confirms via Apply in the sticky footer.
class ConflictDetailRoute extends StatefulWidget {
  const ConflictDetailRoute({required this.conflictId, super.key});

  final String conflictId;

  @override
  State<ConflictDetailRoute> createState() => _ConflictDetailRouteState();
}

class _ConflictDetailRouteState extends State<ConflictDetailRoute> {
  _Side? _selected;
  Future<JournalEntity?>? _localEntryFuture;
  String? _futureKey;

  /// Cache the local-entry lookup keyed by conflict id so the
  /// `FutureBuilder` doesn't re-issue the DB read on every stream tick
  /// (which would also flash a transient null snapshot through the UI).
  /// The Edit & merge nav handler calls [_invalidateLocalEntry] before
  /// leaving so a fresh fetch happens when the user returns.
  Future<JournalEntity?> _localEntryFor(String conflictId) {
    if (_futureKey != conflictId || _localEntryFuture == null) {
      _futureKey = conflictId;
      _localEntryFuture = getIt<JournalDb>().journalEntityById(conflictId);
    }
    return _localEntryFuture!;
  }

  /// Drop the cached local-entry future without rebuilding. The next
  /// `build()` call (e.g. after returning from the edit page) will
  /// re-fetch via [_localEntryFor], avoiding a stale snapshot.
  void _invalidateLocalEntry() {
    _localEntryFuture = null;
    _futureKey = null;
  }

  void _gotoEditMerge(String conflictId) {
    _invalidateLocalEntry();
    beamToNamed('/settings/advanced/conflicts/$conflictId/edit');
  }

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();
    return StreamBuilder<List<Conflict>>(
      stream: db.watchConflictById(widget.conflictId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyScaffoldWithTitle(
            context.messages.conflictDetailLoadErrorTitle,
            body: _ErrorBody(error: snapshot.error),
          );
        }
        final data = snapshot.data ?? const <Conflict>[];
        if (data.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScaffold();
          }
          return EmptyScaffoldWithTitle(
            context.messages.conflictDetailNotFoundTitle,
          );
        }
        final conflict = data.first;
        final remote = fromSerialized(conflict.serialized);
        return FutureBuilder<JournalEntity?>(
          future: _localEntryFor(conflict.id),
          builder: (context, entrySnapshot) {
            if (entrySnapshot.hasError) {
              return EmptyScaffoldWithTitle(
                context.messages.conflictDetailLoadErrorTitle,
                body: _ErrorBody(error: entrySnapshot.error),
              );
            }
            if (entrySnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }
            final local = entrySnapshot.data;
            if (local == null) {
              return EmptyScaffoldWithTitle(
                context.messages.conflictDetailEntryNotFoundTitle,
              );
            }
            final mergedClock = VectorClock.merge(
              local.meta.vectorClock,
              remote.meta.vectorClock,
            );
            // Each side keeps its own metadata; only the vector clock is
            // merged so whichever side the user picks lands with the
            // unified clock. Building the remote side from `local.meta`
            // (the previous behavior) discarded any remote-only meta
            // changes such as a different category id.
            final localResolved = local.copyWith(
              meta: local.meta.copyWith(vectorClock: mergedClock),
            );
            final remoteResolved = remote.copyWith(
              meta: remote.meta.copyWith(vectorClock: mergedClock),
            );
            return _ConflictPickerScaffold(
              conflict: conflict,
              local: localResolved,
              remote: remoteResolved,
              selected: _selected,
              onSelect: (side) => setState(() => _selected = side),
              onApply: () => _apply(localResolved, remoteResolved),
              onEditMerge: () => _gotoEditMerge(conflict.id),
            );
          },
        );
      },
    );
  }

  Future<void> _apply(JournalEntity local, JournalEntity remote) async {
    final winner = switch (_selected) {
      _Side.local => local,
      _Side.remote => remote,
      null => null,
    };
    if (winner == null) return;
    try {
      await getIt<PersistenceLogic>().updateJournalEntity(
        winner,
        winner.meta,
      );
    } catch (e) {
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.conflictApplyFailedTitle,
        description: '$e',
      );
      return;
    }
    if (!mounted) return;
    settingsBeamerDelegate.beamBack();
  }
}
