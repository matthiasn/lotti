import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/vector_clock_counter_cubit.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';
import 'package:wisely/sync/imap.dart';
import 'package:wisely/sync/secure_storage.dart';
import 'package:wisely/sync/vector_clock.dart';
import 'package:wisely/utils/audio_utils.dart';

import 'audio_notes_cubit.dart';
import 'audio_recorder_state.dart';

var uuid = const Uuid();

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  late final EncryptionCubit _encryptionCubit;
  late final VectorClockCubit _vectorClockCubit;
  late final AudioNotesCubit _audioNotesCubit;
  late ImapSyncClient imapSyncClient;

  final FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  AudioNote? _audioNote;
  final DeviceLocation _deviceLocation = DeviceLocation();

  AudioRecorderCubit({
    required EncryptionCubit encryptionCubit,
    required VectorClockCubit vectorClockCubit,
    required AudioNotesCubit audioNotesCubit,
  }) : super(AudioRecorderState(
          status: AudioRecorderStatus.initializing,
          decibels: 0.0,
          progress: const Duration(minutes: 0),
        )) {
    _encryptionCubit = encryptionCubit;
    _audioNotesCubit = audioNotesCubit;
    _vectorClockCubit = vectorClockCubit;

    imapClientInit();

    _myRecorder?.openAudioSession().then((value) {
      emit(state.copyWith(status: AudioRecorderStatus.initialized));
      _myRecorder?.setSubscriptionDuration(const Duration(milliseconds: 500));
      _myRecorder?.onProgress?.listen((event) {
        updateProgress(event);
      });
    });
  }

  Future<void> imapClientInit() async {
    await _encryptionCubit.loadSyncConfig();
    ImapConfig? imapConfig =
        _encryptionCubit.state.maybeWhen((sharedKey, imapConfig) {
      return imapConfig!;
    }, orElse: () {});
    if (imapConfig != null) {
      imapSyncClient = ImapSyncClient(imapConfig, _audioNotesCubit);
    }
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

  // TODO: refactor/implement properly
  void saveEncryptedImapPoC(String subject, String json) async {
    String? b64Secret = await SecureStorage.readValue('sharedSecret');

    if (_audioNote != null) {
      File? audioFile = await AudioUtils.getAudioFile(_audioNote!);
      if (b64Secret != null) {
        String encryptedMessage = encryptSalsa(json, b64Secret);
        imapSyncClient.saveImapMessage(subject, encryptedMessage, null);

        if (audioFile != null) {
          int fileLength = audioFile.lengthSync();
          if (fileLength > 0) {
            File encryptedFile = File('${audioFile.path}.aes');
            encryptFile(audioFile, encryptedFile, b64Secret);
            imapSyncClient.saveImapMessage(
                subject, encryptedMessage, encryptedFile);
          }
        }
      }
    }
  }

  void _saveAudioNoteJson() async {
    if (_audioNote != null) {
      _audioNote = _audioNote?.copyWith(updatedAt: DateTime.now());
      assignVectorClock();
      String json = await AudioUtils.saveAudioNoteJson(_audioNote!);
      saveEncryptedImapPoC('subject', json);
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
    emit(state.copyWith(status: AudioRecorderStatus.stopped));
  }

  @override
  Future<void> close() async {
    super.close();
    _myRecorder?.stopRecorder();
  }
}
