import 'package:lotti/classes/journal_entities.dart';

/// Which side of a conflict an entry belongs to: the version currently in the
/// journal ([local]) or the incoming version recorded on the conflict row
/// ([remote]).
enum ConflictSide { local, remote }

// --- Pure helpers (no Flutter context) -------------------------------------

Duration? audioDuration(JournalEntity entity) {
  return switch (entity) {
    JournalAudio(:final data) => data.duration,
    _ => null,
  };
}

String formatDuration(Duration duration) {
  final total = duration.inSeconds.abs();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}
