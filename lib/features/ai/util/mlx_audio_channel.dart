import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;

/// Native bridge for MLX Audio on macOS.
///
/// The channel is intentionally small and data-oriented: Flutter owns the
/// provider/model configuration and progress UI, while Swift owns MLX model
/// loading, Hugging Face downloads, AVFoundation decoding, and audio playback.
/// The native bridge ships only on macOS — iOS, Android, Linux, and Windows
/// do not register the plugin, and every method short-circuits to an
/// `unsupported` result so callers never see a [MissingPluginException]. On
/// Intel macOS the plugin is registered but the Swift side reports
/// [MlxAudioModelStatus.unsupported] for each model.
class MlxAudioChannel {
  MlxAudioChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    EventChannel? realtimeEventChannel,
  }) : _methodChannel = methodChannel ?? _defaultMethodChannel,
       _eventChannel = eventChannel ?? _defaultEventChannel,
       _realtimeEventChannel =
           realtimeEventChannel ?? _defaultRealtimeEventChannel;

  static const _defaultMethodChannel = MethodChannel(
    'com.matthiasn.lotti/mlx_audio',
  );
  static const _defaultEventChannel = EventChannel(
    'com.matthiasn.lotti/mlx_audio/events',
  );
  static const _defaultRealtimeEventChannel = EventChannel(
    'com.matthiasn.lotti/mlx_audio/realtime_events',
  );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final EventChannel _realtimeEventChannel;

  /// True when this build can run the native MLX Audio bridge.
  ///
  /// The bridge ships only on macOS; every other platform short-circuits to
  /// `unsupported` so the channel never raises [MissingPluginException]. The
  /// flag reads through [platform.isMacOS] so tests can flip it.
  bool get _isPlatformSupported => platform.isMacOS;

  PlatformException _unsupportedPlatformException() {
    return PlatformException(
      code: 'UNSUPPORTED',
      message: 'MLX Audio is only supported on macOS.',
    );
  }

  /// Broadcast stream of model download/install progress from the native side.
  /// Empty on unsupported platforms.
  Stream<MlxAudioModelDownloadProgress> get downloadProgressStream {
    if (!_isPlatformSupported) {
      return const Stream<MlxAudioModelDownloadProgress>.empty();
    }
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, Object?>.from(event as Map);
      return MlxAudioModelDownloadProgress.fromMap(map);
    });
  }

  /// Broadcast stream of live transcription events (partial/final transcripts,
  /// errors) emitted during [startRealtimeTranscription]. Empty on unsupported
  /// platforms.
  Stream<MlxAudioRealtimeEvent> get realtimeTranscriptionEvents {
    if (!_isPlatformSupported) {
      return const Stream<MlxAudioRealtimeEvent>.empty();
    }
    return _realtimeEventChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, Object?>.from(event as Map);
      return MlxAudioRealtimeEvent.fromMap(map);
    });
  }

  /// Queries the install/download status of [modelId]. Returns an `unsupported`
  /// result off-macOS and a `failed` result if the native call errors (it never
  /// throws, unlike the action methods below).
  Future<MlxAudioModelDownloadProgress> getModelStatus(String modelId) async {
    if (!_isPlatformSupported) {
      return MlxAudioModelDownloadProgress.unsupported(modelId);
    }
    try {
      final result = await _methodChannel.invokeMapMethod<String, Object?>(
        'getModelStatus',
        {'modelId': modelId},
      );
      return MlxAudioModelDownloadProgress.fromMap({
        'modelId': modelId,
        ...?result,
      });
    } on MissingPluginException {
      return MlxAudioModelDownloadProgress.unsupported(modelId);
    } on PlatformException catch (e) {
      _logPlatformException('getModelStatus', e);
      return MlxAudioModelDownloadProgress(
        modelId: modelId,
        status: MlxAudioModelStatus.failed,
        message: e.message,
      );
    }
  }

  /// Starts a download/install of [modelId]; progress arrives on
  /// [downloadProgressStream]. Throws on unsupported platforms.
  Future<void> installModel(String modelId) async {
    if (!_isPlatformSupported) {
      throw _unsupportedPlatformException();
    }
    await _methodChannel.invokeMethod<void>(
      'installModel',
      {'modelId': modelId},
    );
  }

  /// Transcribes the audio file at [filePath] with [modelId]. Optional
  /// [speechDictionaryTerms] bias recognition toward domain words; [language]
  /// pins the language; [enableSpeakerDiarization] requests speaker labels.
  /// Throws on unsupported platforms.
  Future<MlxAudioTranscriptionResult> transcribeFile({
    required String filePath,
    required String modelId,
    List<String> speechDictionaryTerms = const [],
    String? language,
    bool enableSpeakerDiarization = false,
  }) async {
    if (!_isPlatformSupported) {
      throw _unsupportedPlatformException();
    }
    final result = await _methodChannel.invokeMapMethod<String, Object?>(
      'transcribeFile',
      {
        'filePath': filePath,
        'modelId': modelId,
        'speechDictionaryTerms': speechDictionaryTerms,
        'language': language,
        'enableSpeakerDiarization': enableSpeakerDiarization,
      },
    );
    return MlxAudioTranscriptionResult.fromMap(result ?? const {});
  }

  /// Like [transcribeFile] but takes the audio inline as base64 instead of a
  /// file path. Throws on unsupported platforms.
  Future<MlxAudioTranscriptionResult> transcribeBase64Audio({
    required String audioBase64,
    required String modelId,
    List<String> speechDictionaryTerms = const [],
    String? language,
    bool enableSpeakerDiarization = false,
  }) async {
    if (!_isPlatformSupported) {
      throw _unsupportedPlatformException();
    }
    final result = await _methodChannel.invokeMapMethod<String, Object?>(
      'transcribeBase64Audio',
      {
        'audioBase64': audioBase64,
        'modelId': modelId,
        'speechDictionaryTerms': speechDictionaryTerms,
        'language': language,
        'enableSpeakerDiarization': enableSpeakerDiarization,
      },
    );
    return MlxAudioTranscriptionResult.fromMap(result ?? const {});
  }

  /// Synthesizes [text] to speech with the TTS [modelId] and plays it natively.
  /// Throws on unsupported platforms.
  Future<void> speakText({
    required String text,
    required String modelId,
    String? language,
  }) async {
    if (!_isPlatformSupported) {
      throw _unsupportedPlatformException();
    }
    await _methodChannel.invokeMethod<void>(
      'speakText',
      {
        'text': text,
        'modelId': modelId,
        'language': language,
      },
    );
  }

  /// Stops any in-progress speech playback. No-op on unsupported platforms.
  Future<void> stopSpeaking() async {
    if (!_isPlatformSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('stopSpeaking');
  }

  /// Opens a streaming transcription session for [modelId]; feed audio via
  /// [appendRealtimePcm] and read results from [realtimeTranscriptionEvents].
  /// [delayPreset] tunes the partial-result latency/accuracy trade-off
  /// (e.g. 'subtitle'). Throws on unsupported platforms.
  Future<void> startRealtimeTranscription({
    required String modelId,
    String? language,
    String delayPreset = 'subtitle',
  }) async {
    if (!_isPlatformSupported) {
      throw _unsupportedPlatformException();
    }
    await _methodChannel.invokeMethod<void>(
      'startRealtimeTranscription',
      {
        'modelId': modelId,
        'language': language,
        'delayPreset': delayPreset,
      },
    );
  }

  /// Feeds a chunk of 16-bit PCM audio into the active realtime session.
  /// No-op on unsupported platforms.
  Future<void> appendRealtimePcm(Uint8List pcm16) async {
    if (!_isPlatformSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>(
      'appendRealtimePcm',
      {'pcm16': pcm16},
    );
  }

  /// Ends the realtime session and flushes the final transcript (delivered via
  /// [realtimeTranscriptionEvents]). No-op on unsupported platforms.
  Future<void> stopRealtimeTranscription() async {
    if (!_isPlatformSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('stopRealtimeTranscription');
  }

  /// Aborts the realtime session immediately, discarding pending audio. No-op
  /// on unsupported platforms.
  Future<void> cancelRealtimeTranscription() async {
    if (!_isPlatformSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('cancelRealtimeTranscription');
  }

  void _logPlatformException(String method, PlatformException error) {
    try {
      getIt<DomainLogger>().log(
        LogDomain.speech,
        'MLX Audio channel $method failed: $error',
        subDomain: method,
      );
    } catch (_) {
      // LoggingService may not be registered in tests.
    }
  }
}

enum MlxAudioRealtimeEventType {
  provisional,
  confirmed,
  display,
  stats,
  done,
  error,
}

class MlxAudioRealtimeEvent {
  const MlxAudioRealtimeEvent({
    required this.type,
    this.text,
    this.confirmedText,
    this.provisionalText,
    this.message,
    this.encodedWindowCount,
    this.totalAudioSeconds,
    this.tokensPerSecond,
    this.realTimeFactor,
    this.peakMemoryGB,
  });

  factory MlxAudioRealtimeEvent.fromMap(Map<String, Object?> map) {
    return MlxAudioRealtimeEvent(
      type: _typeFromString(map['type'] as String?),
      text: map['text'] as String?,
      confirmedText: map['confirmedText'] as String?,
      provisionalText: map['provisionalText'] as String?,
      message: map['message'] as String?,
      encodedWindowCount: (map['encodedWindowCount'] as num?)?.toInt(),
      totalAudioSeconds: (map['totalAudioSeconds'] as num?)?.toDouble(),
      tokensPerSecond: (map['tokensPerSecond'] as num?)?.toDouble(),
      realTimeFactor: (map['realTimeFactor'] as num?)?.toDouble(),
      peakMemoryGB: (map['peakMemoryGB'] as num?)?.toDouble(),
    );
  }

  final MlxAudioRealtimeEventType type;
  final String? text;
  final String? confirmedText;
  final String? provisionalText;
  final String? message;
  final int? encodedWindowCount;
  final double? totalAudioSeconds;
  final double? tokensPerSecond;
  final double? realTimeFactor;
  final double? peakMemoryGB;

  static MlxAudioRealtimeEventType _typeFromString(String? value) {
    return switch (value) {
      'transcription.provisional' => MlxAudioRealtimeEventType.provisional,
      'transcription.confirmed' => MlxAudioRealtimeEventType.confirmed,
      'transcription.display' => MlxAudioRealtimeEventType.display,
      'transcription.stats' => MlxAudioRealtimeEventType.stats,
      'transcription.done' => MlxAudioRealtimeEventType.done,
      'transcription.error' || _ => MlxAudioRealtimeEventType.error,
    };
  }
}

enum MlxAudioModelStatus {
  unsupported,
  notInstalled,
  downloading,
  installed,
  failed,
}

class MlxAudioModelDownloadProgress {
  const MlxAudioModelDownloadProgress({
    required this.modelId,
    required this.status,
    this.progress,
    this.completedUnitCount,
    this.totalUnitCount,
    this.message,
  });

  factory MlxAudioModelDownloadProgress.unsupported(String modelId) {
    return MlxAudioModelDownloadProgress(
      modelId: modelId,
      status: MlxAudioModelStatus.unsupported,
    );
  }

  factory MlxAudioModelDownloadProgress.fromMap(Map<String, Object?> map) {
    return MlxAudioModelDownloadProgress(
      modelId: map['modelId'] as String? ?? '',
      status: _statusFromString(map['status'] as String?),
      progress: (map['progress'] as num?)?.toDouble(),
      completedUnitCount: (map['completedUnitCount'] as num?)?.toInt(),
      totalUnitCount: (map['totalUnitCount'] as num?)?.toInt(),
      message: map['message'] as String?,
    );
  }

  final String modelId;
  final MlxAudioModelStatus status;
  final double? progress;
  final int? completedUnitCount;
  final int? totalUnitCount;
  final String? message;

  bool get hasMeasuredProgress =>
      normalizedProgress != null || status == MlxAudioModelStatus.installed;

  double? get normalizedProgress {
    if (status == MlxAudioModelStatus.installed) {
      return 1;
    }

    final total = totalUnitCount ?? 0;
    final completed = completedUnitCount ?? 0;
    if (total > 0) {
      return (completed / total).clamp(0, 1).toDouble();
    }

    final progressValue = progress;
    if (progressValue != null && progressValue.isFinite) {
      if (progressValue <= 0) {
        return null;
      }
      return progressValue.clamp(0, 1).toDouble();
    }

    return null;
  }

  int? get percentComplete {
    final progressValue = normalizedProgress;
    if (progressValue == null) {
      return null;
    }
    return (progressValue * 100).clamp(0, 100).floor();
  }

  bool get canInstall =>
      status == MlxAudioModelStatus.notInstalled ||
      status == MlxAudioModelStatus.failed;

  static MlxAudioModelStatus _statusFromString(String? value) {
    return switch (value) {
      'installed' => MlxAudioModelStatus.installed,
      'downloading' => MlxAudioModelStatus.downloading,
      'notInstalled' => MlxAudioModelStatus.notInstalled,
      'failed' => MlxAudioModelStatus.failed,
      'unsupported' || _ => MlxAudioModelStatus.unsupported,
    };
  }
}

class MlxAudioTranscriptionResult {
  const MlxAudioTranscriptionResult({
    required this.text,
    this.detectedLanguage,
    this.processingTimeMs,
    this.diarizationStatus,
  });

  factory MlxAudioTranscriptionResult.fromMap(Map<String, Object?> map) {
    return MlxAudioTranscriptionResult(
      text: map['text'] as String? ?? '',
      detectedLanguage: map['detectedLanguage'] as String?,
      processingTimeMs: (map['processingTimeMs'] as num?)?.toInt(),
      diarizationStatus: map['diarizationStatus'] as String?,
    );
  }

  final String text;
  final String? detectedLanguage;
  final int? processingTimeMs;
  final String? diarizationStatus;
}

final mlxAudioChannelProvider = Provider<MlxAudioChannel>((ref) {
  return MlxAudioChannel();
});
