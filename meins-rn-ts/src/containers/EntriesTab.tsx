import React, { memo } from 'react'
import { StyleSheet, View } from 'react-native'
import Colors from 'src/constants/colors'
import { PlaybackList } from 'src/components/PlaybackList'

function EntriesTab() {
  return (
    <View style={styles.container}>
      <PlaybackList />
    </View>
  )
}

export default memo(EntriesTab)

const styles = StyleSheet.create({
  container: {
    paddingTop: 50,
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.darkCharcoal,
  },
})
