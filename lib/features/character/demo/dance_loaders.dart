/// Loaders + parsers for the optional dance-track side files (word-level lyrics
/// and Rhubarb lip-sync cues), shared by the live player and the offline frame
/// composer so the two read the data identically.
///
/// The parse functions are pure (JSON map in, typed records out) and unit-
/// testable; the `load*` wrappers add the file IO (absent file → empty list, so
/// a track without lyrics/cues simply renders without captions or mouth motion).
library;

import 'dart:convert';
import 'dart:io';

import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';

/// Parses the `words` array of a synced-lyrics JSON document. Skips entries
/// without both timestamps; defaults missing voice to `lead` and section to ''.
List<DanceWord> parseDanceWords(Map<String, Object?> json) {
  return ((json['words'] as List?) ?? const [])
      .cast<Map<String, Object?>>()
      .where((w) => w['start_sec'] != null && w['end_sec'] != null)
      .map(
        (w) => (
          start: (w['start_sec']! as num).toDouble(),
          end: (w['end_sec']! as num).toDouble(),
          word: (w['word'] as String?) ?? '',
          voice: (w['voice'] as String?) ?? 'lead',
          section: (w['section'] as String?) ?? '',
        ),
      )
      .toList();
}

/// Parses the `cues` array of a Rhubarb lip-sync JSON document. Defaults a
/// missing shape to `X` (mouth closed / rest).
List<DanceCue> parseDanceCues(Map<String, Object?> json) {
  return ((json['cues'] as List?) ?? const [])
      .cast<Map<String, Object?>>()
      .map(
        (c) => (
          start: (c['start_sec']! as num).toDouble(),
          end: (c['end_sec']! as num).toDouble(),
          shape: (c['shape'] as String?) ?? 'X',
        ),
      )
      .toList();
}

/// Loads word-level lyrics from [path] (absent → no captions / no singing).
/// Parse failures degrade gracefully to an empty list.
Future<List<DanceWord>> loadDanceWords(String path) async {
  final file = File(path);
  if (!file.existsSync()) return const [];
  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return parseDanceWords(json);
  } catch (_) {
    return const [];
  }
}

/// Loads the Rhubarb lip-sync cue track from [path] (absent → no mouth motion).
/// Parse failures degrade gracefully to an empty list.
Future<List<DanceCue>> loadDanceCues(String path) async {
  final file = File(path);
  if (!file.existsSync()) return const [];
  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return parseDanceCues(json);
  } catch (_) {
    return const [];
  }
}
