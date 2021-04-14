import AudioRecorderPlayer from 'react-native-audio-recorder-player';
import {GestureResponderEvent, StyleSheet, Text, TouchableOpacity, View} from 'react-native';
import React, {useState} from 'react';
import {useTranslation} from 'react-i18next';
import Colors from 'src/constants/colors';

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    width: '100%',
    backgroundColor: Colors.lightBleu,
  },
  info: {
    marginTop: 20,
  },
  button: {
    backgroundColor: Colors.white,
    width: 160,
    height: 32,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
});

interface PlayerState {
  currentPositionSec?: number;
  currentDurationSec?: number;
  playTime?: string;
  duration?: string;
  recordTime?: string;
  recordSecs?: number;
}

function RecorderButton({
  title,
  onPress,
}: {
  title: string;
  onPress: (event: GestureResponderEvent) => void;
}) {
  return (
    <TouchableOpacity style={styles.button} onPress={onPress}>
      <Text>{title}</Text>
    </TouchableOpacity>
  );
}

export function AudioRecorder() {
  const {t} = useTranslation();

  const [audioRecorderPlayer] = useState(new AudioRecorderPlayer());
  const [state, setState] = useState<PlayerState>({} as PlayerState);
  const [uri, setUri] = useState<string>();

  async function onPressPlay() {
    await audioRecorderPlayer.startPlayer(uri);
    audioRecorderPlayer.addPlayBackListener((e: any) => {
      setState({
        currentPositionSec: e.current_position,
        currentDurationSec: e.duration,
        playTime: audioRecorderPlayer.mmssss(Math.floor(e.current_position)),
        duration: audioRecorderPlayer.mmssss(Math.floor(e.duration)),
      });
      return;
    });
  }

  async function onPressPause() {
    await audioRecorderPlayer.pausePlayer();
  }

  async function onPressRecord() {
    const fileName = `${new Date().getTime()}.m4a`;
    const res = await audioRecorderPlayer.startRecorder(fileName);
    audioRecorderPlayer.addRecordBackListener((e: any) => {
      setState({
        recordSecs: e.current_position,
        recordTime: audioRecorderPlayer.mmssss(Math.floor(e.current_position)),
      });
      return;
    });
    setUri(res);
  }

  async function onPressStopRecorder() {
    await audioRecorderPlayer.stopRecorder();
    audioRecorderPlayer.removeRecordBackListener();
    setState({
      recordSecs: 0,
    });
  }

  async function onPressStopPlayer() {
    await audioRecorderPlayer.stopPlayer();
  }

  return (
    <View style={styles.container}>
      <RecorderButton title={t('play')} onPress={onPressPlay} />
      <RecorderButton title={t('stopPlayer')} onPress={onPressStopPlayer} />
      <RecorderButton title={t('pause')} onPress={onPressPause} />
      <RecorderButton title={t('record')} onPress={onPressRecord} />
      <RecorderButton title={t('stopRecorder')} onPress={onPressStopRecorder} />
      <View style={styles.info}>
        <Text>recordTime: ${state.recordTime}</Text>
        <Text>playTime: ${state.playTime}</Text>
        <Text>duration: ${state.duration}</Text>
      </View>
    </View>
  );
}
