import React, { memo } from 'react'
import { StyleSheet, View } from 'react-native'
import Colors from 'src/constants/colors'
import { AudioAssistant } from 'src/components/AudioAssistant'

function ListenTab() {
  return (
    <View style={styles.container}>
      <AudioAssistant />
    </View>
  )
}

export default memo(ListenTab)

const styles = StyleSheet.create({
  container: {
    paddingTop: 50,
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.darkCharcoal,
  },
})
