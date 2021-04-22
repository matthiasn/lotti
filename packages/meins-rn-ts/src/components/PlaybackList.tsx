import AudioRecorderPlayer from 'react-native-audio-recorder-player'
import { GestureResponderEvent, StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import React, { useState } from 'react'
import Colors from 'src/constants/colors'
import Icon from 'react-native-vector-icons/FontAwesome'
import { useMachine } from '@xstate/react'
import { realm } from 'src/db/realmPersistence'
import { playbackMachine } from 'src/xstate/entriesMachine'

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'column',
    justifyContent: 'flex-start',
    alignItems: 'center',
    width: '100%',
    paddingTop: 32,
    backgroundColor: Colors.darkBlueGrey,
  },
  recordingRow: {
    flexDirection: 'row',
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
    width: '100%',
    paddingVertical: 12,
    paddingLeft: 32,
  },
  infoText: {
    fontVariant: ['tabular-nums'],
    color: Colors.lightBleu,
    fontSize: 24,
    fontWeight: '100',
  },
  icon: {
    paddingRight: 16,
  },
})

function RecorderButton({
  enabled,
  onPress,
  iconName,
}: {
  enabled: boolean
  iconName: string
  onPress: (event: GestureResponderEvent) => void
}) {
  function onPressButton(event: GestureResponderEvent) {
    if (enabled) {
      onPress(event)
    }
  }
  const color = enabled ? Colors.blueGrey : Colors.darkBlueGrey

  return (
    <TouchableOpacity onPress={onPressButton}>
      <Icon style={styles.icon} name={iconName} size={32} color={color} />
    </TouchableOpacity>
  )
}

function PlaybackRow({ value }: { value: any }) {
  const [current, send] = useMachine(playbackMachine)
  const [audioRecorderPlayer] = useState(new AudioRecorderPlayer())
  const isStopped = current.value === 'stopped'
  const isPlaying = current.value === 'playing'
  const isPaused = current.value === 'paused'

  async function onPressPause() {
    send('PAUSE')
    await audioRecorderPlayer.pausePlayer()
  }

  async function onPressStopPlayer() {
    send('STOP')
    await audioRecorderPlayer.stopPlayer()
  }

  async function onPressPlay() {
    send('PLAY')
    await audioRecorderPlayer.startPlayer(value.uri)
    audioRecorderPlayer.addPlayBackListener((e: any) => {
      const playTime = audioRecorderPlayer.mmssss(Math.floor(e.current_position))
      const duration = audioRecorderPlayer.mmssss(Math.floor(e.duration))
      send({
        type: 'PLAY_PROGRESS',
        currentPositionSec: e.current_position,
        durationSec: e.duration,
        playTime,
        duration,
      })

      if (playTime === duration) {
        audioRecorderPlayer.stopPlayer()
        send('STOP')
      }

      return
    })
  }
  return (
    <View style={styles.recordingRow} key={value.timestamp}>
      {(isStopped || isPaused) && (
        <RecorderButton enabled={true} iconName={'play'} onPress={onPressPlay} />
      )}
      {isPlaying && <RecorderButton enabled={true} iconName={'pause'} onPress={onPressPause} />}
      <RecorderButton enabled={isPlaying} iconName={'stop'} onPress={onPressStopPlayer} />
      <Text style={styles.infoText}>{new Date(value.timestamp).toLocaleString()}</Text>
    </View>
  )
}

export function PlaybackList() {
  const [, setLatestUpdate] = useState(0)
  const [entries] = useState(realm.objects('Entry').sorted('timestamp', true))

  entries.addListener(() => {
    setLatestUpdate(new Date().getTime())
  })

  return (
    <View style={styles.container}>
      {entries.map((value: any) => (
        <PlaybackRow value={value} key={value.timestamp} />
      ))}
    </View>
  )
}
