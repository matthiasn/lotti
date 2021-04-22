import { PermissionsAndroid, Platform } from 'react-native'

async function requestRecordAudioPermissionAndroid(): Promise<boolean> {
  const granted = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO, {
    title: 'Microphone Permission',
    message: '[Permission explanation]',
    buttonNeutral: 'Ask Me Later',
    buttonNegative: 'Cancel',
    buttonPositive: 'OK',
  })
  return granted === PermissionsAndroid.RESULTS.GRANTED
}

export async function requestRecordAudioPermission(): Promise<boolean> {
  let recordAudioRequest: Promise<boolean>
  if (Platform.OS == 'android') {
    // For Android, we need to explicitly ask
    recordAudioRequest = requestRecordAudioPermissionAndroid()
  } else {
    // iOS automatically asks for permission
    recordAudioRequest = new Promise(function (resolve, _) {
      resolve(true)
    })
  }
  return recordAudioRequest
}
