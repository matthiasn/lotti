import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/get_it.dart';

/// Identity key for a waveform computation: which [audio] and how many
/// amplitude buckets to render.
///
/// Equality and [hashCode] are deliberately based only on the audio file
/// identity (entry id + file + directory) and [bucketCount], not the full
/// [JournalAudio]. That keeps the [audioWaveform] provider from recomputing
/// when unrelated entry metadata (e.g. edits to linked tasks) changes while the
/// same underlying file is being visualized.
@immutable
class AudioWaveformRequest {
  const AudioWaveformRequest({
    required this.audio,
    required this.bucketCount,
  });

  /// The audio entry whose waveform is requested.
  final JournalAudio audio;

  /// Number of amplitude bars the painter expects (drives downsampling).
  final int bucketCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AudioWaveformRequest &&
        other.bucketCount == bucketCount &&
        other.audio.meta.id == audio.meta.id &&
        other.audio.data.audioFile == audio.data.audioFile &&
        other.audio.data.audioDirectory == audio.data.audioDirectory;
  }

  @override
  int get hashCode => Object.hash(
    audio.meta.id,
    audio.data.audioFile,
    audio.data.audioDirectory,
    bucketCount,
  );
}

/// Resolves the waveform data for a [AudioWaveformRequest] via
/// [AudioWaveformService] (disk cache + extraction), returning `null` when the
/// source file is missing or extraction fails.
///
/// Extraction is comparatively expensive, so the result is pinned with a
/// 15-minute keep-alive: the provider stays cached while a player card is
/// repeatedly scrolled in/out of view, then auto-releases so long sessions
/// don't accumulate amplitude lists for every clip ever shown. The keep-alive
/// link is closed early on dispose by cancelling the timer.
final FutureProviderFamily<AudioWaveformData?, AudioWaveformRequest>
audioWaveformProvider = FutureProvider.autoDispose
    .family<AudioWaveformData?, AudioWaveformRequest>(
      audioWaveform,
      name: 'audioWaveformProvider',
    );
Future<AudioWaveformData?> audioWaveform(
  Ref ref,
  AudioWaveformRequest request,
) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 15), link.close);
  ref.onDispose(timer.cancel);

  final service = getIt<AudioWaveformService>();
  return service.loadWaveform(
    request.audio,
    targetBuckets: request.bucketCount,
  );
}
