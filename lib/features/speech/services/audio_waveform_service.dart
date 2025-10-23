import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:just_waveform/just_waveform.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// Schema version for cached waveform payloads.
const int _waveformCacheVersion = 1;
const int audioWaveformCacheVersion = _waveformCacheVersion;

/// Maximum supported audio duration for waveform extraction.
const Duration _defaultMaxDuration = Duration(minutes: 3);

/// Maximum number of cached waveform files retained on disk.
const int _maxCacheEntries = 1000;

/// Maximum length for sanitized IDs used in temporary filenames.
const int _maxTempFileIdLength = 60;

/// Weightings used when blending peak and RMS amplitudes.
const double _peakWeight = 0.7;
const double _rmsWeight = 0.3;

/// Zoom level tuned for ~200 buckets across typical journal clips.
const WaveformZoom _defaultZoom = WaveformZoom.pixelsPerSecond(120);

/// Result of waveform extraction for use in the UI.
class AudioWaveformData {
  AudioWaveformData({
    required this.amplitudes,
    required this.bucketDuration,
    required this.audioDuration,
  });

  final List<double> amplitudes;
  final Duration bucketDuration;
  final Duration audioDuration;
}

/// Serialisable payload stored on disk so waveforms can be reused.
class _AudioWaveformCachePayload {
  _AudioWaveformCachePayload({
    required this.version,
    required this.audioFileRelativePath,
    required this.audioFileSizeBytes,
    required this.audioFileModifiedAt,
    required this.audioDurationMs,
    required this.bucketDurationMicros,
    required this.amplitudes,
    required this.sampleCount,
  });

  factory _AudioWaveformCachePayload.fromJson(Map<String, dynamic> json) {
    final amplitudes = (json['amplitudes'] as List<dynamic>)
        .map((dynamic value) => (value as num).toDouble())
        .toList(growable: false);
    return _AudioWaveformCachePayload(
      version: json['version'] as int,
      audioFileRelativePath: json['audioFileRelativePath'] as String,
      audioFileSizeBytes: json['audioFileSizeBytes'] as int,
      audioFileModifiedAt: DateTime.fromMillisecondsSinceEpoch(
        json['audioFileModifiedAt'] as int,
        isUtc: true,
      ),
      audioDurationMs: json['audioDurationMs'] as int,
      bucketDurationMicros: json['bucketDurationMicros'] as int,
      amplitudes: amplitudes,
      sampleCount: json['sampleCount'] as int,
    );
  }

  final int version;
  final String audioFileRelativePath;
  final int audioFileSizeBytes;
  final DateTime audioFileModifiedAt;
  final int audioDurationMs;
  final int bucketDurationMicros;
  final List<double> amplitudes;
  final int sampleCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'audioFileRelativePath': audioFileRelativePath,
        'audioFileSizeBytes': audioFileSizeBytes,
        'audioFileModifiedAt': audioFileModifiedAt.millisecondsSinceEpoch,
        'audioDurationMs': audioDurationMs,
        'bucketDurationMicros': bucketDurationMicros,
        'amplitudes': amplitudes,
        'sampleCount': sampleCount,
      };
}

typedef AudioWaveformExtractor = Future<Waveform> Function({
  required File audioFile,
  required File waveOutFile,
  required WaveformZoom zoom,
});

Future<Waveform> _defaultWaveformExtractor({
  required File audioFile,
  required File waveOutFile,
  required WaveformZoom zoom,
}) async {
  final logging =
      getIt.isRegistered<LoggingService>() ? getIt<LoggingService>() : null;
  try {
    Waveform? waveform;
    final stream = JustWaveform.extract(
      audioInFile: audioFile,
      waveOutFile: waveOutFile,
      zoom: zoom,
    );
    await for (final progress in stream) {
      waveform = progress.waveform ?? waveform;
    }
    if (waveform == null) {
      throw StateError(
        'Waveform extraction completed without emitting waveform data.',
      );
    }
    return waveform;
  } catch (error, stackTrace) {
    logging?.captureException(
      error,
      domain: 'audio_waveform_extractor',
      stackTrace: stackTrace,
    );
    rethrow;
  } finally {
    try {
      if (waveOutFile.existsSync()) {
        waveOutFile.deleteSync();
      }
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
}

/// Service responsible for extracting and caching audio waveform data.
class AudioWaveformService {
  AudioWaveformService({
    AudioWaveformExtractor? extractor,
    Duration maxSupportedDuration = _defaultMaxDuration,
    WaveformZoom zoom = _defaultZoom,
  })  : _extractor = extractor ?? _defaultWaveformExtractor,
        _maxSupportedDuration = maxSupportedDuration,
        _zoom = zoom;

  final AudioWaveformExtractor _extractor;
  final Duration _maxSupportedDuration;
  final WaveformZoom _zoom;

  LoggingService get _loggingService => getIt<LoggingService>();

  Directory get _documentsDirectory => getDocumentsDirectory();

  Directory get _cacheDirectory =>
      Directory(p.join(_documentsDirectory.path, 'audio_waveforms'));

  /// Load (or compute) waveform data for the given [audio]. Returns `null`
  /// when the audio exceeds the supported duration or the source file is
  /// missing.
  Future<AudioWaveformData?> loadWaveform(
    JournalAudio audio, {
    required int targetBuckets,
  }) async {
    final bucketTarget = math.max(1, targetBuckets);
    if (audio.data.duration > _maxSupportedDuration) {
      _loggingService.captureEvent(
        'Skipping waveform generation for long clip '
        '(${audio.data.duration.inSeconds}s > ${_maxSupportedDuration.inSeconds}s)',
        domain: 'audio_waveform_service',
        subDomain: 'duration_gate',
      );
      return null;
    }

    final audioPath = await AudioUtils.getFullAudioPath(audio);
    final audioFile = File(audioPath);
    if (!audioFile.existsSync()) {
      _loggingService.captureEvent(
        'Audio file not found for waveform extraction: $audioPath',
        domain: 'audio_waveform_service',
        subDomain: 'missing_source',
      );
      return null;
    }

    final stat = audioFile.statSync();
    final cacheKey = _cacheFile(audio.meta.id, bucketTarget);
    if (cacheKey.existsSync()) {
      final cached = await _readCache(cacheKey);
      if (cached != null &&
          cached.version == _waveformCacheVersion &&
          cached.sampleCount == bucketTarget &&
          cached.audioFileRelativePath ==
              AudioUtils.getRelativeAudioPath(audio) &&
          cached.audioFileSizeBytes == stat.size &&
          cached.audioFileModifiedAt.isAtSameMomentAs(
            stat.modified.toUtc(),
          )) {
        return AudioWaveformData(
          amplitudes: cached.amplitudes,
          bucketDuration: Duration(
            microseconds: cached.bucketDurationMicros,
          ),
          audioDuration: Duration(milliseconds: cached.audioDurationMs),
        );
      }
    }

    await _cacheDirectory.create(recursive: true);

    final sanitizedId = _sanitizeTempId(audio.meta.id);
    final tempWaveOutFile = File(
      p.join(
        Directory.systemTemp.path,
        'waveform_${sanitizedId}_${DateTime.now().microsecondsSinceEpoch}.wave',
      ),
    );

    try {
      final waveform = await _extractor(
        audioFile: audioFile,
        waveOutFile: tempWaveOutFile,
        zoom: _zoom,
      );

      final normalized = _normalizeWaveform(
        waveform: waveform,
        targetBuckets: bucketTarget,
      );
      final bucketDuration = _bucketDuration(
        waveform: waveform,
        reducedBuckets: normalized.length,
      );
      final data = AudioWaveformData(
        amplitudes: normalized,
        bucketDuration: bucketDuration,
        audioDuration: waveform.duration,
      );

      final payload = _AudioWaveformCachePayload(
        version: _waveformCacheVersion,
        audioFileRelativePath: AudioUtils.getRelativeAudioPath(audio),
        audioFileSizeBytes: stat.size,
        audioFileModifiedAt: stat.modified.toUtc(),
        audioDurationMs: waveform.duration.inMilliseconds,
        bucketDurationMicros: bucketDuration.inMicroseconds,
        amplitudes: normalized,
        sampleCount: normalized.length,
      );
      await _writeCache(cacheKey, payload);
      return data;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'audio_waveform_service',
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      try {
        if (tempWaveOutFile.existsSync()) {
          tempWaveOutFile.deleteSync();
        }
      } catch (_) {
        // Ignore cleanup failures.
      }
    }
  }

  String _sanitizeTempId(String rawId) {
    final sanitized =
        rawId.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_').trim();
    final safe = sanitized.isEmpty ? 'audio' : sanitized;
    if (safe.length <= _maxTempFileIdLength) {
      return safe;
    }
    return safe.substring(0, _maxTempFileIdLength);
  }

  File _cacheFile(String audioId, int bucketCount) {
    final sanitizedId = audioId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final prefix = sanitizedId.length >= 2 ? sanitizedId.substring(0, 2) : '00';
    final subDirectory = Directory(p.join(_cacheDirectory.path, prefix))
      ..createSync(recursive: true);
    final safeFileName = '${sanitizedId}_$bucketCount.json';
    return File(p.join(subDirectory.path, safeFileName));
  }

  Future<_AudioWaveformCachePayload?> _readCache(File cacheFile) async {
    try {
      final jsonString = cacheFile.readAsStringSync();
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return _AudioWaveformCachePayload.fromJson(decoded);
      }
      _loggingService.captureEvent(
        'Unexpected cache payload shape: $decoded',
        domain: 'audio_waveform_service',
        subDomain: 'cache_read',
      );
      return null;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'audio_waveform_service',
        subDomain: 'cache_read',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _writeCache(
    File cacheFile,
    _AudioWaveformCachePayload payload,
  ) async {
    try {
      cacheFile.parent.createSync(recursive: true);
      cacheFile.writeAsStringSync(jsonEncode(payload.toJson()));
      await _pruneCacheIfNeeded();
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'audio_waveform_service',
        subDomain: 'cache_write',
        stackTrace: stackTrace,
      );
    }
  }

  List<double> _normalizeWaveform({
    required Waveform waveform,
    required int targetBuckets,
  }) {
    final pixelCount = waveform.length;
    if (pixelCount == 0) {
      return <double>[];
    }

    final maxAmplitude = waveform.flags == 0 ? 32768.0 : 128.0;
    final pixelAmplitudes = List<double>.generate(
      pixelCount,
      (int index) {
        final min = waveform.getPixelMin(index).abs();
        final max = waveform.getPixelMax(index).abs();
        return math.min(
          1,
          math.max(min, max) / maxAmplitude,
        );
      },
      growable: false,
    );

    if (pixelCount <= targetBuckets) {
      return pixelAmplitudes;
    }

    final bucketSize = pixelCount / targetBuckets;
    final reduced = List<double>.generate(targetBuckets, (int bucketIndex) {
      final start = (bucketIndex * bucketSize).floor();
      final end = math.min(pixelCount, ((bucketIndex + 1) * bucketSize).ceil());
      var peak = 0.0;
      var sumSquares = 0.0;
      final span = math.max(1, end - start);
      for (var i = start; i < end; i++) {
        final value = pixelAmplitudes[i];
        if (value > peak) {
          peak = value;
        }
        sumSquares += value * value;
      }
      final rms = math.sqrt(sumSquares / span).clamp(0.0, 1.0);
      final weightSum =
          (_peakWeight + _rmsWeight).clamp(0.0001, double.infinity);
      final blended = ((peak * _peakWeight) + (rms * _rmsWeight)) / weightSum;
      return blended.clamp(0.0, 1.0);
    });

    return reduced;
  }

  Duration _bucketDuration({
    required Waveform waveform,
    required int reducedBuckets,
  }) {
    if (reducedBuckets == 0 || waveform.length == 0) {
      return Duration.zero;
    }

    final secondsPerPixel =
        waveform.samplesPerPixel / waveform.sampleRate.toDouble();
    final pixelsPerBucket = waveform.length / reducedBuckets;
    final bucketSeconds = secondsPerPixel * pixelsPerBucket;
    return Duration(
      microseconds: (bucketSeconds * 1000000).round(),
    );
  }

  Future<void> _pruneCacheIfNeeded() async {
    try {
      if (!_cacheDirectory.existsSync()) {
        return;
      }
      final files = _cacheDirectory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .toList()
        ..sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      if (files.length <= _maxCacheEntries) {
        return;
      }

      final toRemove = files.length - _maxCacheEntries;
      for (var i = 0; i < toRemove; i++) {
        try {
          files[i].deleteSync();
        } catch (_) {
          // Ignore cleanup failures.
        }
      }
      if (toRemove > 0) {
        _loggingService.captureEvent(
          'Pruned $toRemove waveform cache files (now ${files.length - toRemove} entries)',
          domain: 'audio_waveform_service',
          subDomain: 'cache_prune',
        );
      }
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'audio_waveform_service',
        subDomain: 'cache_prune',
        stackTrace: stackTrace,
      );
    }
  }
}
