import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/audio/recorder_state.dart';
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/blocs/sync/outbound_queue_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/journal_db_entities.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/vector_clock.dart';
import 'package:wisely/utils/audio_utils.dart';

import '../journal_entities_cubit.dart';

var uuid = const Uuid();
AudioRecorderState initialState = AudioRecorderState(
  status: AudioRecorderStatus.initializing,
  decibels: 0.0,
  progress: const Duration(minutes: 0),
);

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  late final VectorClockCubit _vectorClockCubit;
  late final JournalEntitiesCubit _journalEntitiesCubit;
  late final OutboundQueueCubit _outboundQueueCubit;
  late final PersistenceCubit _persistenceCubit;

  final FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  AudioNote? _audioNote;
  final DeviceLocation _deviceLocation = DeviceLocation();

  AudioRecorderCubit({
    required VectorClockCubit vectorClockCubit,
    required OutboundQueueCubit outboundQueueCubit,
    required JournalEntitiesCubit journalEntitiesCubit,
    required PersistenceCubit persistenceCubit,
  }) : super(initialState) {
    _journalEntitiesCubit = journalEntitiesCubit;
    _outboundQueueCubit = outboundQueueCubit;
    _vectorClockCubit = vectorClockCubit;
    _persistenceCubit = persistenceCubit;
    _openAudioSession();
  }

  Future<void> _openAudioSession() async {
    if (Platform.isAndroid) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }
    }

    _myRecorder?.openAudioSession().then((value) {
      debugPrint('openAudioSession $value');
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

  VectorClock assignVectorClock() {
    String host = _vectorClockCubit.state.host;
    int nextAvailableCounter = _vectorClockCubit.state.nextAvailableCounter;
    VectorClock next = VectorClock(<String, int>{host: nextAvailableCounter});
    _audioNote = _audioNote?.copyWith(vectorClock: next);
    _vectorClockCubit.increment();
    return next;
  }

  void _saveAudioNoteJson() async {
    if (_audioNote != null) {
      _audioNote = _audioNote?.copyWith(updatedAt: DateTime.now());
      VectorClock next = assignVectorClock();
      await AudioUtils.saveAudioNoteJson(_audioNote!);
      File? audioFile = await AudioUtils.getAudioFile(_audioNote!);

      await _outboundQueueCubit.enqueueMessage(
        SyncMessage.journalEntity(
          journalEntity: _audioNote!,
          vectorClock: next,
        ),
        attachment: audioFile,
      );

      _journalEntitiesCubit.save(_audioNote!);
    }
  }

  void _addGeolocation() async {
    _deviceLocation.getCurrentGeoLocation().then((Geolocation? geolocation) {
      if (geolocation != null) {
        _audioNote = _audioNote?.copyWith(geolocation: geolocation);
        _saveAudioNoteJson();
      }
    });
  }

  void record() async {
    DateTime created = DateTime.now();
    String fileName =
        '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
    String day = DateFormat('yyyy-MM-dd').format(created);
    String relativePath = '/audio/$day/';
    String directory = await AudioUtils.createAssetDirectory(relativePath);
    String filePath = '$directory$fileName';
    debugPrint('RECORD: $filePath');
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

    if (_audioNote != null) {
      AudioNote audioNote = _audioNote!;

      JournalDbAudio journalDbAudio = JournalDbAudio(
        audioDirectory: audioNote.audioDirectory,
        duration: audioNote.duration,
        audioFile: audioNote.audioFile,
        dateTo: audioNote.createdAt.add(audioNote.duration),
        dateFrom: audioNote.createdAt,
      );

      debugPrint(journalDbAudio.toString());
      _persistenceCubit.create(journalDbAudio,
          geolocation: audioNote.geolocation);
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _myRecorder?.stopRecorder();
  }
}
