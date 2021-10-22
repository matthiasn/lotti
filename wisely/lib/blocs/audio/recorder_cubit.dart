import 'package:bloc/bloc.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/audio/recorder_state.dart';
import 'package:wisely/blocs/sync/imap_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/vector_clock.dart';
import 'package:wisely/utils/audio_utils.dart';

import '../audio_notes_cubit.dart';

var uuid = const Uuid();
AudioRecorderState initialState = AudioRecorderState(
  status: AudioRecorderStatus.initializing,
  decibels: 0.0,
  progress: const Duration(minutes: 0),
);

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  late final VectorClockCubit _vectorClockCubit;
  late final AudioNotesCubit _audioNotesCubit;
  late final ImapCubit _imapCubit;

  final FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  AudioNote? _audioNote;
  final DeviceLocation _deviceLocation = DeviceLocation();

  AudioRecorderCubit({
    required VectorClockCubit vectorClockCubit,
    required ImapCubit imapCubit,
    required AudioNotesCubit audioNotesCubit,
  }) : super(initialState) {
    _audioNotesCubit = audioNotesCubit;
    _imapCubit = imapCubit;
    _vectorClockCubit = vectorClockCubit;

    _myRecorder?.openAudioSession().then((value) {
      emit(state.copyWith(status: AudioRecorderStatus.initialized));
      _myRecorder?.setSubscriptionDuration(const Duration(milliseconds: 500));
      _myRecorder?.onProgress?.listen((event) {
        updateProgress(event);
      });
    });
  }

  void updateProgress(RecordingDisposition event) {
    emit(state.copyWith(
      progress: event.duration,
      decibels: event.decibels ?? 0.0,
    ));
  }

  void assignVectorClock() {
    String host = _vectorClockCubit.state.host;
    int nextAvailableCounter = _vectorClockCubit.state.nextAvailableCounter;
    _audioNote = _audioNote?.copyWith(
        vectorClock: VectorClock(<String, int>{host: nextAvailableCounter}));
    _vectorClockCubit.increment();
  }

  void _saveAudioNoteJson() async {
    if (_audioNote != null) {
      _audioNote = _audioNote?.copyWith(updatedAt: DateTime.now());
      assignVectorClock();
      String json = await AudioUtils.saveAudioNoteJson(_audioNote!);
      _imapCubit.saveEncryptedImap(_audioNote!);
      _audioNotesCubit.save(_audioNote!);
    }
  }

  void _addGeolocation() async {
    _deviceLocation.getCurrentLocation().then((LocationData locationData) {
      _audioNote = _audioNote?.copyWith(
        latitude: locationData.latitude,
        longitude: locationData.longitude,
      );
      _saveAudioNoteJson();
    });
  }

  void record() async {
    DateTime created = DateTime.now();
    String fileName =
        '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
    String day = DateFormat('yyyy-MM-dd').format(created);
    String relativePath = '/audio/$day/';
    String directory = await AudioUtils.createAudioDirectory(relativePath);
    String filePath = '${directory}$fileName';
    print('RECORD: ${filePath}');
    String timezone = await FlutterNativeTimezone.getLocalTimezone();

    _audioNote = AudioNote(
        id: uuid.v1(options: {'msecs': created.millisecondsSinceEpoch}),
        timestamp: created.millisecondsSinceEpoch,
        createdAt: created,
        utcOffset: created.timeZoneOffset.inMinutes,
        timezone: timezone,
        audioFile: fileName,
        audioDirectory: relativePath,
        duration: const Duration(seconds: 0));

    _saveAudioNoteJson();
    _addGeolocation();

    _myRecorder
        ?.startRecorder(
      toFile: filePath,
      codec: Codec.aacADTS,
      sampleRate: 48000,
      bitRate: 128000,
    )
        .then((value) {
      emit(state.copyWith(status: AudioRecorderStatus.recording));
    });
  }

  void stop() async {
    await _myRecorder?.stopRecorder();
    _audioNote = _audioNote?.copyWith(duration: state.progress);
    _saveAudioNoteJson();
    emit(initialState);
  }

  @override
  Future<void> close() async {
    super.close();
    _myRecorder?.stopRecorder();
  }
}
