import AudioRecorderPlayer from 'react-native-audio-recorder-player'
import { GestureResponderEvent, StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import React, { useState } from 'react'
import { useTranslation } from 'react-i18next'
import Colors from 'src/constants/colors'
import Icon from 'react-native-vector-icons/FontAwesome'
import { audioRecorderMachine } from 'src/xstate/audioRecorder'
import { useMachine } from '@xstate/react'

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
    height: 50,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    flexDirection: 'row',
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonText: {
    fontWeight: 'bold',
    color: Colors.darkBlueGrey,
    width: 100,
  },
  infoText: {
    fontVariant: ['tabular-nums'],
    color: Colors.lightBleu,
    fontSize: 24,
    fontWeight: '100',
  },
  icon: {
    marginRight: 12,
    marginLeft: 8,
  },
})

function RecorderButton({
  enabled,
  title,
  onPress,
  iconName,
}: {
  enabled: boolean
  title: string
  iconName: string
  onPress: (event: GestureResponderEvent) => void
}) {
  function onPressButton(event: GestureResponderEvent) {
    if (enabled) {
      onPress(event)
    }
  }

  return (
    <TouchableOpacity
      style={enabled ? styles.button : [styles.button, styles.buttonDisabled]}
      onPress={onPressButton}>
      <Icon style={styles.icon} name={iconName} size={32} color={Colors.blueGrey} />
      <Text style={styles.buttonText}>{title}</Text>
    </TouchableOpacity>
  )
}

export function AudioRecorder() {
  const { t } = useTranslation()

  const [current, send] = useMachine(audioRecorderMachine)
  const [audioRecorderPlayer] = useState(new AudioRecorderPlayer())
  const [uri, setUri] = useState<string>()

  const isEmpty = current.value === 'empty'
  const isStopped = current.value === 'stopped'
  const isRecording = current.value === 'recording'
  const isPlaying = current.value === 'playing'
  const isPaused = current.value === 'paused'

  async function onPressPlay() {
    send('PLAY')
    await audioRecorderPlayer.startPlayer(uri)
    audioRecorderPlayer.addPlayBackListener((e: any) => {
      send({
        type: 'PLAY_PROGRESS',
        currentPositionSec: e.current_position,
        currentDurationSec: e.duration,
        playTime: audioRecorderPlayer.mmssss(Math.floor(e.current_position)),
        duration: audioRecorderPlayer.mmssss(Math.floor(e.duration)),
      })
      return
    })
  }

  async function onPressPause() {
    send('PAUSE')
    await audioRecorderPlayer.pausePlayer()
  }

  async function onPressRecord() {
    const timestamp = new Date().getTime()
    const audioFile = `${timestamp}.m4a`
    const text = ''
    send({ type: 'RECORD', audioFile, timestamp, text })
    const res = await audioRecorderPlayer.startRecorder(audioFile)
    audioRecorderPlayer.addRecordBackListener((e: any) => {
      send({
        type: 'RECORD_PROGRESS',
        recordSecs: e.current_position,
        recordTime: audioRecorderPlayer.mmssss(Math.floor(e.current_position)),
      })
      return
    })
    setUri(res)
  }

  async function onPressStopRecorder() {
    send('STOP')
    await audioRecorderPlayer.stopRecorder()
    audioRecorderPlayer.removeRecordBackListener()
    send({ type: 'RECORD_PROGRESS', recordSecs: 0, recordTime: '00:00:00' })
  }

  async function onPressStopPlayer() {
    send('STOP')
    await audioRecorderPlayer.stopPlayer()
  }

  return (
    <View style={styles.container}>
      {(isStopped || isPaused) && (
        <RecorderButton
          enabled={isStopped || isPaused}
          iconName={'play'}
          title={t('play')}
          onPress={onPressPlay}
        />
      )}
      {isPlaying && (
        <RecorderButton
          enabled={isPlaying}
          iconName={'stop'}
          title={t('stop')}
          onPress={onPressStopPlayer}
        />
      )}
      {isPlaying && (
        <RecorderButton
          enabled={isPlaying}
          iconName={'pause'}
          title={t('pause')}
          onPress={onPressPause}
        />
      )}
      {(isEmpty || isStopped) && (
        <RecorderButton
          enabled={isStopped || isEmpty}
          iconName={'microphone'}
          title={t('record')}
          onPress={onPressRecord}
        />
      )}
      {isRecording && (
        <RecorderButton
          enabled={isRecording}
          iconName={'stop'}
          title={t('stop')}
          onPress={onPressStopRecorder}
        />
      )}
      <View style={styles.info}>
        {isRecording && (
          <Text style={styles.infoText}>
            {current.context.recordTime} / {current.context.recordTime}
          </Text>
        )}
        {(isPlaying || isPaused) && (
          <Text style={styles.infoText}>
            {current.context.playTime} / {current.context.duration}
          </Text>
        )}
      </View>
    </View>
  )
}
