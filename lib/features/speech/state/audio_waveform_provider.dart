import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_waveform_provider.g.dart';

@immutable
class AudioWaveformRequest {
  const AudioWaveformRequest({
    required this.audio,
    required this.bucketCount,
  });

  final JournalAudio audio;
  final int bucketCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AudioWaveformRequest &&
        other.bucketCount == bucketCount &&
        other.audio.meta.id == audio.meta.id &&
        other.audio.data.audioFile == audio.data.audioFile;
  }

  @override
  int get hashCode =>
      Object.hash(audio.meta.id, audio.data.audioFile, bucketCount);
}

@riverpod
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
