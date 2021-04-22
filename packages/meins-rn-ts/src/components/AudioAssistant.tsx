import { StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import React, { useState } from 'react'
import { useTranslation } from 'react-i18next'
import Colors from 'src/constants/colors'
import Icon from 'react-native-vector-icons/FontAwesome'

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    width: '100%',
    backgroundColor: Colors.darkBlueGrey,
  },
  button: {
    backgroundColor: Colors.lightRed,
    width: 320,
    height: 320,
    borderRadius: 160,
    borderWidth: 8,
    borderColor: Colors.red,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    flexDirection: 'column',
  },
  buttonDisabled: {
    borderColor: Colors.green,
    backgroundColor: Colors.lightGreen,
  },
  buttonText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: Colors.darkBlueGrey,
    marginTop: 32,
  },
  icon: {
    paddingTop: 16,
  },
})

export function AudioAssistant() {
  const { t } = useTranslation()
  const [listenStatus, setListenStatus] = useState(false)

  function toggleListener() {
    setListenStatus(!listenStatus)
  }

  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={listenStatus ? styles.button : [styles.button, styles.buttonDisabled]}
        onPress={toggleListener}>
        <Icon
          style={styles.icon}
          name={'assistive-listening-systems'}
          size={128}
          color={listenStatus ? Colors.red : Colors.green}
        />
        <Text style={styles.buttonText}>
          {listenStatus ? t('stopListening') : t('startListening')}
        </Text>
      </TouchableOpacity>
    </View>
  )
}
