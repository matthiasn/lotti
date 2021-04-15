import AudioRecorderPlayer from 'react-native-audio-recorder-player';
import {GestureResponderEvent, StyleSheet, Text, TouchableOpacity, View} from 'react-native';
import React, {useState} from 'react';
import {useTranslation} from 'react-i18next';
import Colors from 'src/constants/colors';
import Icon from 'react-native-easy-icon/src/index';
import {audioRecorderMachine} from 'src/xstate/audioRecorder'
import {useMachine} from '@xstate/react'

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    width: '100%',
    backgroundColor: Colors.darkBlueGrey,
  },
  info: {
    marginTop: 20,
    color: Colors.lightBleu,
  },
  button: {
    backgroundColor: Colors.lightBleu,
    width: 160,
    height: 40,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    flexDirection: 'row',
  },
  buttonText: {
    fontWeight: 'bold',
    color: Colors.darkBlueGrey,
    width: 100,
  },
  infoText: {
    fontWeight: 'bold',
    color: Colors.lightBleu,
  },
  icon: {
    marginRight: 12,
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
  iconName,
}: {
  title: string;
  iconName: string;
  onPress: (event: GestureResponderEvent) => void;
}) {
  return (
    <TouchableOpacity style={styles.button} onPress={onPress}>
      <Icon
        style={styles.icon}
        name={iconName}
        type="material-community"
        size={32}
        color={Colors.blueGrey}
      />
      <Text style={styles.buttonText}>{title}</Text>
    </TouchableOpacity>
  );
}

export function AudioRecorder() {
  const {t} = useTranslation();

  const [audioRecorderContext, sendAudioRecorder] = useMachine(audioRecorderMachine);
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
      <RecorderButton iconName={'play'} title={t('play')} onPress={onPressPlay} />
      <RecorderButton iconName={'stop'} title={t('stopPlayer')} onPress={onPressStopPlayer} />
      <RecorderButton iconName={'pause'} title={t('pause')} onPress={onPressPause} />
      <RecorderButton iconName={'record'} title={t('record')} onPress={onPressRecord} />
      <RecorderButton iconName={'stop'} title={t('stopRecorder')} onPress={onPressStopRecorder} />
      <View style={styles.info}>
        <Text style={styles.infoText}>recordTime: {state.recordTime}</Text>
        <Text style={styles.infoText}>playTime: {state.playTime}</Text>
        <Text style={styles.infoText}>duration: {state.duration}</Text>
      </View>
    </View>
  );
}
