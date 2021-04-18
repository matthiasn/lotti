import AudioRecorderPlayer from 'react-native-audio-recorder-player'
import { GestureResponderEvent, StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import React, { useState } from 'react'
import Colors from 'src/constants/colors'
import Icon from 'react-native-vector-icons/FontAwesome'
import { useService } from '@xstate/react'
import { realm } from 'src/db/realmPersistence'
import { playbackService } from 'src/xstate/entriesMachine'

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
  },
  button: {
    width: 50,
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
  infoText: {
    fontVariant: ['tabular-nums'],
    color: Colors.lightBleu,
    fontSize: 24,
    fontWeight: '100',
  },
  icon: {
    marginRight: 8,
    marginLeft: 8,
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

  return (
    <TouchableOpacity
      style={enabled ? styles.button : [styles.button, styles.buttonDisabled]}
      onPress={onPressButton}>
      <Icon style={styles.icon} name={iconName} size={32} color={Colors.blueGrey} />
    </TouchableOpacity>
  )
}

function PlaybackRow({ send, value }: { value: any; send: any }) {
  const [audioRecorderPlayer, setAudioRecorderPlayer] = useState(new AudioRecorderPlayer())

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
  return (
    <View style={styles.recordingRow} key={value.timestamp}>
      <RecorderButton enabled={true} iconName={'play'} onPress={onPressPlay} />
      <RecorderButton enabled={true} iconName={'stop'} onPress={onPressStopPlayer} />
      <RecorderButton enabled={true} iconName={'pause'} onPress={onPressPause} />
      <Text style={styles.infoText}>{new Date(value.timestamp).toLocaleString()}</Text>
    </View>
  )
}

export function PlaybackList() {
  const [latestUpdate, setLatestUpdate] = useState(0)
  const [entries, setEntries] = useState(realm.objects('Entry'))
  // entries.addListener((collection) => {
  //   console.log(collection)
  //   setLatestUpdate(new Date().getTime())
  // })
  const [, send] = useService(playbackService)

  return (
    <View style={styles.container}>
      {entries.map((value: any) => (
        <PlaybackRow value={value} send={send} key={value.timestamp} />
      ))}
    </View>
  )
}
