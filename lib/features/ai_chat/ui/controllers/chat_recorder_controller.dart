import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:record/record.dart' as record;

enum ChatRecorderStatus { idle, recording, processing }

class ChatRecorderState {
  // Constructors first per lint
  const ChatRecorderState({
    required this.status,
    required this.amplitudeHistory,
    this.transcript,
    this.error,
  });

  const ChatRecorderState.initial()
      : status = ChatRecorderStatus.idle,
        amplitudeHistory = const <double>[],
        transcript = null,
        error = null;

  // Fields
  final ChatRecorderStatus status;
  final List<double> amplitudeHistory; // dBFS history
  final String? transcript; // last finished transcript waiting to be consumed
  final String? error;

  // Methods
  ChatRecorderState copyWith({
    ChatRecorderStatus? status,
    List<double>? amplitudeHistory,
    String? transcript,
    String? error,
  }) {
    return ChatRecorderState(
      status: status ?? this.status,
      amplitudeHistory: amplitudeHistory ?? this.amplitudeHistory,
      transcript: transcript,
      error: error,
    );
  }
}

class ChatRecorderController extends StateNotifier<ChatRecorderState> {
  ChatRecorderController(this.ref) : super(const ChatRecorderState.initial());

  final Ref ref;

  record.AudioRecorder? _recorder;
  StreamSubscription<record.Amplitude>? _ampSub;
  Timer? _maxTimer;
  Directory? _tempDir;
  String? _filePath;

  static const int _historyMax = 200; // ~4s at 20ms; UI will sample to fit
  static const int maxSeconds = 120;

  Future<void> start() async {
    if (state.status == ChatRecorderStatus.recording) return;
    final recorder = record.AudioRecorder();
    final hasPerm = await recorder.hasPermission();
    if (!hasPerm) {
      state = state.copyWith(error: 'Microphone permission denied');
      await recorder.dispose();
      return;
    }

    try {
      _tempDir = await Directory.systemTemp.createTemp('lotti_chat_rec_');
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _filePath = '${_tempDir!.path}/$fileName';

      await recorder.start(
        const record.RecordConfig(sampleRate: 48000, autoGain: true),
        path: _filePath!,
      );

      _recorder = recorder;

      // Amplitude stream
      _ampSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 20))
          .listen((event) {
        final dBFS = event.current;
        final history = List<double>.from(state.amplitudeHistory)..add(dBFS);
        if (history.length > _historyMax) history.removeAt(0);
        state = state.copyWith(
            status: ChatRecorderStatus.recording, amplitudeHistory: history);
      });

      // Safety stop after maxSeconds
      _maxTimer?.cancel();
      _maxTimer = Timer(const Duration(seconds: maxSeconds), () {
        unawaited(stopAndTranscribe());
      });
    } catch (e) {
      state = state.copyWith(error: 'Failed to start recording: $e');
      await _cleanupInternal();
    }
  }

  Future<void> stopAndTranscribe() async {
    if (_recorder == null) return;
    state = state.copyWith(status: ChatRecorderStatus.processing);
    _maxTimer?.cancel();

    try {
      await _ampSub?.cancel();
      await _recorder!.stop();
    } catch (_) {
      // ignore
    }

    final filePath = _filePath;
    if (filePath == null) {
      await _cleanupInternal();
      state = state.copyWith(
          status: ChatRecorderStatus.idle, error: 'No audio file');
      return;
    }

    try {
      final transcript = await _transcribe(filePath);
      state = state.copyWith(
          status: ChatRecorderStatus.idle, transcript: transcript);
    } catch (e) {
      state = state.copyWith(
          status: ChatRecorderStatus.idle, error: 'Transcription failed: $e');
    } finally {
      await _cleanupInternal();
    }
  }

  /// Cancel current recording and discard audio without transcription.
  Future<void> cancel() async {
    if (state.status != ChatRecorderStatus.recording &&
        state.status != ChatRecorderStatus.processing) {
      return;
    }
    _maxTimer?.cancel();
    try {
      await _ampSub?.cancel();
    } catch (_) {}
    try {
      await _recorder?.stop();
    } catch (_) {}
    await _cleanupInternal();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  // Always Gemini Flash for v1 per requirements
  Future<String> _transcribe(String filePath) async {
    final aiRepo = ref.read(aiConfigRepositoryProvider);
    final providers =
        await aiRepo.getConfigsByType(AiConfigType.inferenceProvider);
    final provider = providers
        .whereType<AiConfigInferenceProvider>()
        .firstWhere(
            (p) => p.inferenceProviderType == InferenceProviderType.gemini,
            orElse: () => throw Exception('No Gemini provider configured'));

    final models = await aiRepo.getConfigsByType(AiConfigType.model);
    final geminiModels = models.whereType<AiConfigModel>().where(
          (m) =>
              m.inferenceProviderId == provider.id &&
              m.inputModalities.contains(Modality.audio),
        );
    final model = geminiModels.firstWhere(
      (m) => m.providerModelId.contains('gemini-2.5-flash'),
      orElse: () => geminiModels.isNotEmpty
          ? geminiModels.first
          : throw Exception('No Gemini audio-capable model configured'),
    );

    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);

    final cloud = ref.read(cloudInferenceRepositoryProvider);
    final buffer = StringBuffer();
    final stream = cloud.generateWithAudio(
      'Transcribe the audio to natural text.',
      model: model.providerModelId,
      audioBase64: audioBase64,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      provider: provider,
      maxCompletionTokens: model.maxCompletionTokens,
    );

    await for (final chunk in stream) {
      final content = chunk.choices?.firstOrNull?.delta?.content ?? '';
      if (content.isNotEmpty) buffer.write(content);
    }
    return buffer.toString();
  }

  // Normalize dBFS history to 0.05..1.0 range for UI
  List<double> getNormalizedAmplitudeHistory() {
    return state.amplitudeHistory.map((dBFS) {
      if (dBFS <= -80) return 0.05;
      if (dBFS >= -10) return 1.0;
      final normalized = (dBFS + 80) / 70; // -80..-10 -> 0..1
      final scaled = normalized * 0.95 + 0.05;
      return scaled.clamp(0.05, 1.0);
    }).toList();
  }

  Future<void> _cleanupInternal() async {
    try {
      await _ampSub?.cancel();
      _ampSub = null;
    } catch (_) {}
    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
    _maxTimer?.cancel();
    _maxTimer = null;
    try {
      if (_filePath != null) {
        final f = File(_filePath!);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } catch (_) {}
    try {
      if (_tempDir != null && _tempDir!.existsSync()) {
        _tempDir!.deleteSync(recursive: true);
      }
    } catch (_) {}
    _tempDir = null;
    _filePath = null;
    // Keep amplitude history so UI shows a bit of trailing bars until next start
  }

  void clearResult() {
    if (state.transcript != null || state.error != null) {
      state = ChatRecorderState(
        status: state.status,
        amplitudeHistory: state.amplitudeHistory,
      );
    }
  }
}

final AutoDisposeStateNotifierProvider<ChatRecorderController,
        ChatRecorderState> chatRecorderControllerProvider =
    StateNotifierProvider.autoDispose<ChatRecorderController,
        ChatRecorderState>((ref) {
  return ChatRecorderController(ref);
});
