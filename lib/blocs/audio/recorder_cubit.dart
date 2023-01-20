import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/location.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:record/record.dart';

AudioRecorderState initialState = AudioRecorderState(
  status: AudioRecorderStatus.initializing,
  decibels: 0,
  progress: Duration.zero,
  showIndicator: false,
);

const intervalMs = 100;

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  AudioRecorderCubit() : super(initialState) {
    if (!Platform.isLinux && !Platform.isWindows) {
      _deviceLocation = DeviceLocation();
    }

    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: intervalMs))
        .listen((Amplitude amp) {
      emit(
        state.copyWith(
          progress: Duration(
            milliseconds: state.progress.inMilliseconds + intervalMs,
          ),
          decibels: amp.current + 160,
        ),
      );
    });
  }

  final _audioRecorder = Record();
  StreamSubscription<Amplitude>? _amplitudeSub;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  String? _linkedId;
  AudioNote? _audioNote;
  DeviceLocation? _deviceLocation;

  Future<void> record({
    String? linkedId,
  }) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final created = DateTime.now();
        final fileName =
            '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
        final day = DateFormat('yyyy-MM-dd').format(created);
        final relativePath = '/audio/$day/';
        final directory = await createAssetDirectory(relativePath);
        final filePath = '${isMacOS ? 'file://' : ''}$directory$fileName';

        _audioNote = AudioNote(
          id: uuid.v1(),
          timestamp: created.millisecondsSinceEpoch,
          createdAt: created,
          utcOffset: created.timeZoneOffset.inMinutes,
          timezone: await getLocalTimezone(),
          audioFile: fileName,
          audioDirectory: relativePath,
          duration: Duration.zero,
        );

        unawaited(_addGeolocation());

        await _audioRecorder.start(
          path: filePath,
          samplingRate: 48000,
        );
      } else {
        _loggingDb.captureEvent(
          'no audio recording permission',
          domain: 'recorder_cubit',
        );
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> stop() async {
    try {
      await _audioRecorder.stop();
      _audioNote = _audioNote?.copyWith(duration: state.progress);
      emit(initialState);

      if (_audioNote != null) {
        await persistenceLogic.createAudioEntry(
          _audioNote!,
          linkedId: _linkedId,
        );
        _linkedId = null;
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> pause() async {
    await _audioRecorder.pause();
  }

  Future<void> resume() async {
    await _audioRecorder.resume();
  }

  void setIndicatorVisible({required bool showIndicator}) {
    emit(state.copyWith(showIndicator: showIndicator));
  }

  Future<void> _addGeolocation() async {
    try {
      await _deviceLocation
          ?.getCurrentGeoLocation()
          .then((Geolocation? geolocation) {
        if (geolocation != null) {
          _audioNote = _audioNote?.copyWith(geolocation: geolocation);
        }
      });
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    await _audioRecorder.dispose();
    await _amplitudeSub?.cancel();
  }
}
